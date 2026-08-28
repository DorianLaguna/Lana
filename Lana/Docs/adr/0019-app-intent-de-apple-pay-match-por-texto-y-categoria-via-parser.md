# ADR-0019: Implementar el App Intent de Apple Pay con match de tarjeta por texto y categoría vía el parser existente

- **Estado:** Aceptada
- **Fecha:** 2026-08-27

## Contexto

ADR-0009 decidió *que* Lana captura Apple Pay vía un App Intent expuesto a
Shortcuts, sobre el trigger de automatización "Wallet". Faltaba decidir *cómo*
implementarlo en dos puntos concretos, cada uno con una alternativa más simple
y más segura que se descartó a propósito:

**1. Cómo resolver a qué tarjeta de Lana corresponde el pago.**

- *Alternativa descartada:* exponer un parámetro `@Parameter` de tipo entidad
  (`CardEntity: AppEntity`) resuelto contra `CardStore`, para que el usuario
  elija la tarjeta de Lana de un picker al armar cada atajo — un valor fijo,
  sin ambigüedad posible en tiempo de ejecución.
- *Elegida:* un parámetro de texto libre (`walletCardName: String`) que recibe
  tal cual el nombre que el trigger de Wallet entrega, emparejado en tiempo de
  ejecución contra las tarjetas reales vía `Card.bestMatch(for:in:)`.

**2. Qué categoría lleva una transacción capturada así.**

- *Alternativa descartada:* guardar siempre sin categoría (`category: nil`),
  dejando que el usuario la asigne al revisar en la bandeja de `needsReview`
  que ya existe — cero dependencia de `FoundationModels` en el intent.
- *Elegida:* pasar el texto del comercio por
  `FoundationModelsExpenseParsing.parse(_:)` (la misma implementación real que
  usa la captura por texto) para sugerir categoría/subcategoría, cayendo a
  `nil` si el modelo no está disponible o falla.

Ambas alternativas descartadas eran más simples y más robustas frente a fallos;
se decidieron las opciones más ambiciosas de forma consciente (elegidas
explícitamente por el usuario del proyecto sobre las conservadoras, 2026-08-27).

## Decisión

**Match de tarjeta por heurística de texto, nunca por picker fijo.**
`Card.bestMatch(for:in:)` (`LanaCore/Models/CardMatching.swift`) prioriza los
últimos 4 dígitos: si el texto de Wallet contiene los últimos 4 de exactamente
una tarjeta, esa gana siempre — es la señal más específica. Si ninguna tarjeta
calza por dígitos, cae a buscar el alias como substring del texto, normalizado
sin acentos ni mayúsculas. Si el resultado es ambiguo (cero o más de una
tarjeta calza) el método regresa `nil` — nunca adivina. El intent entonces
truena con `AddTransactionIntentError.cardNotFound`, un mensaje que apunta al
usuario a revisar el alias en Ajustes → Tarjetas.

Esto es deliberadamente distinto al principio de "guardar nunca se bloquea"
(Docs/CLAUDE.md): un match ambiguo de tarjeta no es ambigüedad de captura (la
que sí se resuelve con `needsReview`), es un error de configuración del atajo
— hay que fallar visible para que el usuario lo note al armarlo, no guardar en
la tarjeta equivocada ni inventar una tercera opción.

**Categoría real vía el parser existente, no `needsReview` desnudo.**
El intent reconstruye `AppDependencies.live()` — la misma composición real que
usa el resto de la app, no una instancia paralela — y si
`parser.availability == .available`, le pasa el `merchant` a
`parse(_:)` solo para extraer `category`/`subcategory`. El monto y la fecha
nunca se le piden al modelo: ya vienen ciertos desde Wallet. Esto es lo
opuesto a "el regex gana sobre el monto" (que aplica cuando el modelo sí
infiere un monto del mismo texto que se está categorizando) — aquí no hay
monto que inferir, así que esa regla no entra en juego.

Independientemente de si se logró categorizar, **la transacción siempre
entra con `needsReview: true`** (ADR-0009) — la categorización es una
conveniencia, nunca la razón para tratar el registro como confirmado.

## Consecuencias

- El match por texto depende de que Wallet nombre la tarjeta de forma
  reconocible contra lo que el usuario capturó en Lana (alias o últimos 4).
  Si el nombre en Wallet no se parece al alias en Lana y no incluye los 4
  dígitos, el atajo falla en cada ejecución hasta que el usuario ajuste el
  alias — a diferencia de un picker fijo, que nunca fallaría por esto.
- Categorizar automáticamente ata la confiabilidad del intent a que
  `FoundationModels` esté disponible y responda a tiempo en una ejecución en
  background sin UI — más lento y con más puntos de falla que simplemente
  guardar sin categoría. El fallback a `nil` cuando falla evita que esto
  bloquee el registro, pero el usuario puede ver transacciones con y sin
  categoría sugerida de forma inconsistente según el momento.
- `AddTransactionIntent` vive en el target de la app (`Lana/Intents/`), no en
  `LanaCore` — necesita `AppDependencies`/Core Data reales, y `LanaCore` solo
  importa `Foundation` (Docs/ARCHITECTURE.md). La heurística de match en sí
  (`Card.bestMatch`) sí es pura y vive en `LanaCore`, con tests reales
  (`CardMatchingTests`, 6 casos incluyendo ambigüedad y acentos) — el intent
  como tal no es testeable con Swift Testing (requiere runtime de
  `AppIntents`/Shortcuts, PLAN.md ya documenta esto como prueba manual).
- Si en el uso real el match por texto resulta demasiado frágil (Wallet
  nombra las tarjetas de forma menos predecible de lo esperado), reconsiderar
  hacia el picker fijo descartado aquí es la primera alternativa a revisitar
  — no requiere cambiar el modelo de datos, solo el tipo del parámetro y quitar
  `Card.bestMatch`.

# ADR-0025: La captura general (voz/texto) también detecta gasto compartido

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

El parser de captura general (`EntryFeature`, usado por texto, voz, y el
widget de Home Screen) nunca detectaba si un gasto era compartido — decir
"pagué la renta, la dividimos a la mitad con Ana" desde fuera del tab
Compartido siempre se guardaba como gasto 100% personal, sin rastro de la
división mencionada. `ParsedSharedTransaction`/`ParsedSharedTransactionBatch`
(`LanaParsing`) ya existían como un `@Generable` separado pensado para esto,
pero no estaban conectados a nada — código muerto desde que se escribieron.

El usuario lo pidió explícitamente: "cuando registro un gasto con voz, veo
que no detecta que es un gasto compartido cuando le digo, entonces quisiera
que también detectara eso... aunque igual debería ser en la lista que
ponen" — anticipando la pregunta real: ¿qué pasa cuando no está claro con
quién se divide o a qué lista pertenece? Se le preguntó directamente y
eligió: si es ambiguo, el gasto se guarda como personal con
`needsReview = true`, nunca se bloquea la captura ni se interrumpe con una
pregunta a mitad de dictado.

## Decisión

**Un solo schema, siempre activo — no un segundo parser.** En vez de
mantener `ParsedSharedTransaction` como un `@Generable` aparte que había
que decidir cuándo invocar (activarlo solo dentro de una lista compartida no
sirve para este caso: la captura general no sabe de antemano si el texto va
a mencionar algo compartido), `ParsedTransaction` (el schema ya usado en
cada captura) gana dos campos nuevos: `payerHint`/`splitHint`, texto libre,
vacíos cuando el texto no menciona haber dividido el gasto con nadie. Un
único `session.respond(...)` por captura, como siempre — el costo es dos
`@Guide` más en el mismo schema, no una segunda sesión de modelo.
`ParsedSharedTransaction`/`ParsedSharedTransactionBatch` se borraron —
completamente superseded, nunca tuvieron un solo call site.

`ParsingPipeline` aplica a `payerHint` el mismo resguardo que ya tenía
`cardHint`: si el texto no contiene literalmente el nombre que el modelo
propuso, se descarta (con la excepción de "yo", que nunca aparece tal cual
en el texto). `ParserInstructions` gana una sección opcional con los
nombres reales de los participantes de las listas compartidas del usuario
— mismo criterio que ya existía para alias de tarjeta: que el modelo
reconozca el nombre real en vez de inventar una variante.

**La resolución (a qué lista, quién es el pagador real) vive en
`LanaCore`, no en `LanaParsing`.** `SharedExpenseMatch.bestMatch(payerHint:
splitHint:in:viewerIdentities:)` (nuevo, `LanaCore/Models/SharedExpenseMatching.swift`)
es una función pura, mismo patrón que `Card.bestMatch` (ADR-0019): busca el
nombre entre los participantes de todas las listas compartidas del usuario
(insensible a acentos/mayúsculas), y "yo" resuelve contra la identidad ya
marcada en cada lista (`viewerIdentities`, ADR-0022). **Ambiguo se trata
igual que "no encontrado" — nunca se adivina con quién se comparte dinero
real**: si el nombre calza con participantes de 2+ listas distintas, o con
ninguno, el resultado es `nil`. `splitHint` solo resuelve dos casos
seguros de texto libre ("igual" → partes iguales entre el roster vigente;
"yo" → nadie más debe nada) — cualquier otra cosa (una proporción descrita
en prosa, o nada mencionado) cae al `defaultSplit` de la lista; parsear una
proporción arbitraria de un string con la confianza necesaria para dividir
dinero real queda fuera de esto, ese caso ya se resuelve a mano en
`SharedExpenseCaptureView`.

**`EntryModel` aplica el match y fuerza `needsReview`.** Gana una
dependencia a `SharedListStore` (protocolo de `LanaCore`, no cruza a
`SharedFeature` — las features no se importan entre sí) y carga
`sharedLists`/`viewerIdentities` en cada `onAppear()`, igual que
`cards`/`allSubcategories`. En `submit()`, cada borrador pasa por
`applySharedMatch(from:to:)`:

- Sin `payerHint` → nada cambia, es el camino de siempre.
- `payerHint` presente y resuelve a una sola lista/participante → el
  borrador queda con `sharedListID`/`payer`/`split` llenos, **y
  `needsReview` se fuerza a `true`** — mismo criterio que Apple Pay/OCR
  (Docs/CLAUDE.md: "todo lo capturado automáticamente entra con
  needsReview"): atribuir dinero real entre personas a partir de una
  heurística de texto merece la misma disciplina que cualquier otra
  captura automática.
- `payerHint` presente pero ambiguo/sin match → el gasto se queda
  personal, `needsReview` también se fuerza — la decisión que el usuario
  eligió explícitamente.

**`DraftCard` hace visible la detección antes de confirmar.** Sin esto,
confirmar habría sido invisible — el usuario nunca vería a dónde fue su
dinero hasta entrar a esa lista compartida después. Cuando
`draft.sharedListID` no es `nil`, aparece una línea "Compartido en
[lista] — pagó [nombre]" con un botón "Quitar" que limpia
`sharedListID`/`payer`/`split` sin borrar el gasto — vuelve a guardarse
como personal, como si el texto nunca hubiera mencionado a nadie. No se
construyó un editor de pagador/split aquí — esa UI ya existe completa en
`SharedExpenseCaptureView` (ADR-0022); duplicarla en `EntryFeature`
mezclaría conceptos de "compartido" en un componente que Cards/Dashboard
también usan para gastos sin esos campos.

## Consecuencias

**Bueno:**

- Decir "lo pagué yo, dividido con Ana" desde cualquier punto de captura
  (texto, voz, el widget) ya no se pierde silenciosamente como un gasto
  100% personal.
- Cuando la señal es ambigua, el usuario se entera (`needsReview`) en vez
  de que el dato simplemente desaparezca sin dejar rastro.
- Ningún módulo ganó una dependencia indebida: `LanaParsing` sigue sin
  saber qué es una lista compartida más allá de una lista de nombres para
  el prompt; la resolución real vive en `LanaCore`, pura y probada sin
  simulador.

**Malo / a vigilar:**

- **No existe manera de convertir, después del hecho, un gasto ya
  guardado como personal en uno compartido** — si la detección falló
  (ambiguo, o el usuario dijo "Quitar" por error), la única forma de
  arreglarlo hoy es borrar ese gasto personal y volver a capturarlo desde
  el tab Compartido. El editor genérico de Dashboard (`EditExpenseModel`)
  no tiene campos de pagador/split (ADR-0022 ya documentó por qué). Si
  esto resulta molesto en la práctica, la solución sería agregar una
  acción "Compartir este gasto" al editor genérico, no duplicar la UI de
  split ahí — pendiente, no se construyó en este cambio.
- `splitHint` solo entiende dos casos ("igual", "yo") — cualquier
  proporción descrita en la frase ("60-40", "yo puse el doble") se
  resuelve al `defaultSplit` de la lista, ignorando lo que de verdad se
  dijo. Es una limitación conocida, no un bug: el costo de parsear con
  confianza una proporción de texto libre para dividir dinero real es
  más alto que el de simplemente dejarlo en el default y que el usuario
  lo corrija si hace falta.
- La accuracy real de `payerHint`/`splitHint` (¿el modelo los llena
  cuando debería, se los inventa cuando no debería?) no está medida
  contra el golden set (`parser-eval`) — la skill `cloudkit-sharing` ya
  advertía que un parser en "modo compartido" tiende a tener accuracy más
  baja que el simple; con un solo schema compartido ahora, vale la pena
  agregar casos de prueba con/sin división mencionada al golden set antes
  de confiar en esto a ciegas.

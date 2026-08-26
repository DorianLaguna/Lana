---
name: foundation-models
description: Cómo usar correctamente el framework FoundationModels de Apple para extraer datos estructurados en iOS, incluyendo @Generable, @Guide, manejo de availability, prewarm y las trampas conocidas. Usa esta skill siempre que el trabajo toque el parser de Lana, LanguageModelSession, structs @Generable, el modelo on-device, Apple Intelligence, o cualquier extracción de texto libre a datos estructurados — aunque el usuario no nombre el framework explícitamente.
---

# FoundationModels en Lana

El modelo del sistema es la única ruta de parseo del proyecto (ADR-0002). Estas son
las reglas para usarlo bien.

## Availability: los cuatro casos

Nunca crees una sesión sin checar primero. Cada caso tiene tratamiento distinto en
UI, y tratarlos como uno solo produce una experiencia mala:

```swift
switch SystemLanguageModel.default.availability {
case .available:
    // Único caso donde el flujo de captura funciona
case .unavailable(.deviceNotEligible):
    // Permanente. Pantalla explicativa, sin botón de reintentar.
case .unavailable(.appleIntelligenceNotEnabled):
    // Recuperable. Botón que lleva a Settings.
case .unavailable(.modelNotReady):
    // Temporal, se está descargando. Mensaje de espera + reintento.
@unknown default:
    // Trátalo como no disponible
}
```

Este chequeo va en el arranque de la app y también antes de cada sesión — el
usuario puede apagar Apple Intelligence mientras la app está abierta.

## Salida estructurada

`@Generable` es la razón por la que este framework le gana a un modelo empaquetado:
la salida cumple el tipo o la llamada falla. No hay JSON roto que parsear.

```swift
@Generable
struct ParsedExpense {
    @Guide(description: "Monto numérico en pesos mexicanos, sin símbolo de moneda")
    let amount: Double

    @Guide(description: "Qué se compró o pagó, en 2 a 4 palabras, en español")
    let concept: String

    @Guide(description: "Categoría del gasto")
    let category: ExpenseCategory

    @Guide(description: "Fecha del gasto si el texto la menciona; nil si no")
    let date: String?
}
```

Para categorías usa un enum `@Generable` en lugar de un `String` con lista en la
descripción. El enum restringe el espacio de salida y elimina las variantes
inventadas.

## Los @Guide son el 80% de la calidad

Un `@Guide` vago produce parseo mediocre y ninguna cantidad de prompt engineering
lo compensa. Sé específico sobre formato, idioma y unidades.

```swift
// Mal
@Guide(description: "el monto")

// Bien
@Guide(description: "Monto numérico en pesos mexicanos, sin símbolo de moneda ni separador de miles")
```

Cuando falle un patrón (ver reportes de `parser-evaluator`), el primer lugar
donde intervenir es el `@Guide`, no el prompt.

## Rendimiento

Llama `session.prewarm()` cuando el usuario abra la pantalla de captura, no cuando
oprima enviar. Carga el modelo en background y hace que la primera respuesta se
sienta inmediata.

Para gastos sueltos usa una sesión nueva por parseo. El contexto multi-turno no
aporta aquí y consume ventana.

Si el parseo tarda lo suficiente para notarse, usa `streamResponse` para ir
mostrando el resultado parcial en lugar de un spinner.

## Lecciones del spike (Fase 0.5) — leer antes de tocar el parser

**`@Guide` no se puede poner por-caso en un enum.** Solo va en stored properties.
Las definiciones de categoría viven en el `@Guide` del campo, construidas desde
una constante de texto. Ponerlo sobre los `case` no compila.

**Nunca pongas cifras en las instrucciones** (ADR-0013). Un ejemplo con "460" se
filtró a las respuestas de frases que no lo mencionaban y tumbó la accuracy de
conteo a 13%. Reglas abstractas y listas de etiquetas: sí. Ejemplos con datos:
nunca.

**Los `@Guide` valen más que el prompt.** Definir cada categoría con ejemplos de
qué entra subió la accuracy de 70% a 95% sin tocar el modelo ni las
instrucciones. Cuando falle un patrón, el primer lugar donde intervenir es el
`@Guide` del campo.

**Describe la forma esperada, no prohibiciones.** "Nunca agregues elementos de
relleno" fue ignorado; "la lista casi siempre contiene exactamente un elemento y
termina ahí" funcionó. Los modelos de este tamaño siguen mejor una descripción de
la salida que una regla negativa.

**Los errores estructurales se limpian con código, no con más prompt.** El modelo
insistía en devolver un segundo gasto con monto 0. Tres rondas de prompt no lo
quitaron; un `filter { $0.monto > 0 }` sí. Un gasto de cero no existe: el filtro
es correcto siempre.

**Un validador con falsos positivos es peor que no tenerlo.** Una versión del
regex marcaba como alucinación montos correctos de cuatro dígitos. Si cada gasto
de cuatro cifras se marca `needsReview`, el usuario aprende a ignorar la bandera
en una semana.

**`necesitaRevision` funciona.** El modelo se autoevalúa con precisión razonable.
Vale la pena usar esa señal para mandar a la bandeja de revisión.

## Trampas conocidas

**El monto se equivoca.** Este es el problema real del framework en apps de
finanzas: ocasionalmente devuelve 30 donde el texto decía 300. Por eso
`AmountValidator` corre siempre sobre el texto crudo y su resultado gana. Si
discrepan, se guarda el del regex y el gasto se marca `needsReview`.

**Los guardrails pueden disparar.** El framework tiene filtros de seguridad que
ocasionalmente rechazan entradas inocuas. Captura ese error y ofrece edición
manual en vez de mostrar un error críptico.

**No es conocimiento general.** El modelo on-device está hecho para clasificación,
extracción y salida estructurada dentro de apps, no para preguntas de mundo. No le
pidas convertir monedas ni saber precios.

**Cambia entre versiones de iOS.** Apple rehizo el modelo entre iOS 26 y 27. Corre
`parser-evaluator` contra cada beta.

## Verificar antes de escribir código

Este framework se mueve rápido. Antes de usar una API que no esté en este
documento, confirma la firma actual en la documentación oficial en lugar de
asumirla. Un ejemplo desactualizado cuesta más que una búsqueda.

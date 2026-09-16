# ADR-0049: El evento guarda por dónde entró el movimiento

- **Estado:** Aceptada
- **Fecha:** 2026-09-16
- **Relacionada:** ADR-0005 (eventos append-only), ADR-0009 (Apple Pay vía
  Shortcuts), ADR-0042 (registrado se deriva del movimiento ligado al recurrente)

## Contexto

La fila "Por revisar" de Hoy (rediseño, sección 02) dice **"2 de Apple Pay"** a
la derecha. Es lo que le dice al usuario si lo pendiente lo dejó él dudando al
dictar o si entró solo mientras pagaba, y cambia qué espera encontrar al abrir
la bandeja.

El dato no existía. `Expense` sabe si necesita revisión, pero no por qué camino
llegó: un pago de Apple Pay y un dictado ambiguo se guardan con el mismo evento y
los mismos campos. Se consideraron tres salidas:

- **Inferirlo.** Lo de Apple Pay siempre trae tarjeta y entra con `needsReview`.
  Pero un dictado con tarjeta resuelta y monto dudoso tiene la misma forma, y el
  dato existe justo para distinguir esos dos casos. Adivinar ahí engaña.
- **Una marca booleana `isFromApplePay`.** Resuelve la fila de hoy y nada más; la
  próxima pregunta ("¿cuánto registro dictando y cuánto a mano?") pediría otra
  marca.
- **Un campo de origen en el evento raíz**, con un catálogo cerrado.

## Decisión

**`ExpenseAdded` e `IncomeAdded` llevan `source: CaptureSource?`**: `dictation`,
`applePay`, `manual` o `recurring`. `Expense` lo expone tal cual.

- Lo fija quien crea el movimiento: el borrador del parser (`dictation`), el
  intent de Wallet (`applePay`), el formulario de registro manual y el de lista
  compartida (`manual`), y el registro de un recurrente (`recurring`).
- **Ninguna corrección lo cambia.** `ExpenseCorrected` no tiene el campo:
  confirmar un pago de Apple Pay desde la bandeja no lo vuelve manual. Mismo
  criterio que `recurringItemID`.
- **Es opcional y no se migra.** El payload es JSON (`CDEvent.payload`), así que
  los eventos viejos decodifican con `nil` sin tocar el esquema de Core Data ni
  el de CloudKit. Lo registrado antes **no se rellena**: no hay de dónde sacarlo
  sin inferir, que es lo que se descartó.

"2 de Apple Pay" cuenta los pendientes con `source == .applePay`. Si no hay
ninguno, la fila no dice nada más: lo demás lo dictó el usuario.

## Consecuencias

- La fila de Hoy dice de dónde vino lo pendiente, y el dato queda disponible para
  cualquier otra pantalla o tool del Análisis sin otro cambio de modelo.
- **Durante un tiempo el conteo se queda corto.** Los pendientes de Apple Pay
  registrados antes de esta versión no tienen origen y no cuentan. Con
  `needsReview` la bandeja se vacía rápido, así que el desfase dura poco, pero
  en la primera apertura tras actualizar la fila puede no decir nada teniendo
  pagos de Apple Pay pendientes.
- En un iPhone con una versión anterior sincronizada por iCloud, el campo se
  ignora al decodificar. No rompe nada, pero ese dispositivo no lo muestra.
- El catálogo es cerrado. Un origen nuevo —los tickets por OCR (ADR-0010), fuera
  de v1.0— es un caso más del enum. Un iPhone con una versión anterior no podría
  decodificar ese valor desconocido, y **el evento entero fallaría al leerse**.
  Antes de agregar un caso hay que hacer que la decodificación degrade a `nil`.

## Qué haría reconsiderar esto

- Que haga falta el origen de lo registrado antes. La salida sería un evento de
  anotación aparte, nunca reescribir los eventos viejos.
- Que el origen empiece a decidir comportamiento (reglas distintas de revisión
  por camino). Ahí deja de ser un dato de lectura y merece su propio ADR.

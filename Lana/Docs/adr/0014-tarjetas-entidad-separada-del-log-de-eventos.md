# ADR-0014: `Card` es una entidad de referencia editable, no un evento

- **Estado:** Aceptada
- **Fecha:** 2026-08-26

## Contexto

`Card` (alias, últimos 4 dígitos, límite, día de corte, fecha límite)
existe en `LanaCore` desde Fase 1, pero nunca se persistió: no hay entidad
de Core Data, no hay protocolo de store. Para que Fase 6.5 (CRUD de
tarjetas) exista de verdad hay que decidir cómo guardarla.

Dos caminos:

**A. Como eventos**, igual que los gastos (`CardAdded`, `CardEdited`...).
Consistente con ADR-0005, pero una tarjeta no es un hecho financiero que
haya que auditar en el tiempo — es configuración que el usuario corrige
libremente (se equivocó de día de corte, subió el límite). Forzarla al
molde de eventos-inmutables-que-se-corrigen-con-otro-evento es más
ceremonia sin beneficio real: nadie necesita saber que hace tres meses el
límite era otro.

**B. Como entidad plana y mutable**, igual que `CDSharedList` (que ya
existe con ese mismo perfil: nombre editable, sin historial de eventos
propio). CRUD directo sobre la fila.

Aparte de la forma del dato, está el problema de **cuántos
`NSPersistentContainer` conviven en el proceso**. El comentario en
`LanaManagedObjectModel.swift` ya documenta que containers concurrentes
con el mismo modelo crashearon en la práctica durante Fase 2 — cualquier
store nuevo que abra su propio container repite ese riesgo.

## Decisión

`Card` se persiste como entidad plana (`CDCard`), con el mismo perfil que
`CDSharedList`: todos los atributos opcionales (regla de CloudKit), sin
relación con `CDEvent`, editable in-place vía CRUD normal — no genera
eventos, no participa del log append-only.

Se agrega también `CDVocabularyEntry` (persistencia real para
`CorrectionVocabularyStore`, movido a `LanaCore` en el mismo cambio) con
el mismo perfil.

Ambas entidades nuevas viven en el **mismo** `NSManagedObjectModel` y el
**mismo** `NSPersistentContainer` que ya usa `CoreDataExpenseStore` — esa
misma clase gana conformancias nuevas (`extension CoreDataExpenseStore:
CardStore`, `extension CoreDataExpenseStore: CorrectionVocabularyStore`)
en archivos separados, en vez de instanciar un segundo store con su
propio container.

## Consecuencias

- Editar una tarjeta es un `save` normal, sin corrección-de-evento — más
  simple de leer y de probar que forzarla al molde de ADR-0005.
- El saldo de una tarjeta (`CardLedger`) sigue derivándose de eventos de
  gasto (`ExpenseEvent` con `paymentMethod: .credit`) — `Card` en sí misma
  nunca tiene saldo propio que persistir, solo metadata.
- Un solo container sirve cuatro entidades (`CDEvent`, `CDSharedList`,
  `CDCard`, `CDVocabularyEntry`). Evita repetir el crash de Fase 2. El
  costo es que `CoreDataExpenseStore` acumula responsabilidades (tres
  protocolos) — aceptable porque todas comparten el mismo ciclo de vida
  de persistencia real; si algún día se vuelve difícil de seguir, el
  refactor es dividir el *archivo*, no el *container*.
- `CorrectionVocabularyStore` deja de vivir en `LanaParsing` — pasa a
  `LanaCore` con `category: String` en vez de `ExpenseCategory`, porque
  `SettingsFeature` (que solo puede depender de `LanaCore`/`LanaDesign`)
  necesita mostrarlo y borrarlo.

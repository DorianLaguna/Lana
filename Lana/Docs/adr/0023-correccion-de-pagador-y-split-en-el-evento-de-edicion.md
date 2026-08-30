# ADR-0023: `ExpenseCorrected` gana `payer`/`split`, para que editar un gasto compartido sí los cambie

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

ADR-0022 le dio a `SharedExpenseCaptureView` una UI completa de edición
(monto, concepto, categoría, fecha, pagador, split) que llama a
`SharedListDetailModel.updateExpense(id:...)`, documentado ahí como
apoyándose en el mismo mecanismo que `EditExpenseModel`: guardar con el
mismo `id` hace que `ExpenseStore.save(_:)` lo trate como corrección.

El usuario probó ese flujo en su iPhone — cambiar la regla de división a
"Proporcional" y capturar cuánto gana cada quien — y reportó que no se
guardaba, sin mensaje de error visible. Un primer intento de arreglo
(`@FocusState` mal cerrado dejando el teclado sin confirmar el último
campo antes de `save()`) no lo resolvió; el usuario confirmó explícitamente
que seguía sin guardarse.

La causa real estaba un nivel más abajo: `ExpenseCorrected`
(`LanaCore/Models/ExpenseEvent.swift`) nunca tuvo campos `payer`/`split`.
`ResolvedTransaction.applying(_ correction:)` (`LanaCore/Ledger/ResolvedTransaction.swift`)
conservaba siempre el `payer`/`split` del evento **original**, sin importar
qué trajera la corrección — porque la corrección no tenía dónde traerlos.
`CoreDataExpenseStore.makeEvent(for:correcting:)` tampoco los pasaba al
construir el `ExpenseCorrected`. El formulario de edición sí capturaba los
valores nuevos correctamente; se perdían en el evento antes de llegar al
pliegue.

Un test existente (`SharedExpenseUpdateDeleteTests.updateExpenseCambiaPagadorYSplit`)
pasaba en falso: usaba `InMemoryExpenseStore`, que sobreescribe un
diccionario por id en vez de simular corrección sobre eventos — no podía
detectar este bug porque no tiene la misma semántica que `CoreDataExpenseStore`
en producción.

## Decisión

`ExpenseCorrected` gana `payer: ParticipantID?` y `split: SplitRule?`, con
el mismo significado que el resto de sus campos opcionales: `nil` conserva
el valor anterior, un valor lo reemplaza desde ese punto del historial en
adelante (la proporción sigue congelándose por evento, ADR-0007 — corregir
el split no reescribe correcciones previas).

`ResolvedTransaction.applying(_:)` pasa a usar
`correction.payer ?? payer` / `correction.split ?? split` en vez de
`payer`/`split` a secas. `CoreDataExpenseStore.makeEvent(for:correcting:)`
pasa `expense.payer`/`expense.split` al construir la corrección.

Se agregaron dos pruebas nuevas en `ExpenseProjectionTests` (LanaCore, sin
Core Data) que confirman el pliegue puro, y una en
`CoreDataExpenseStoreTests` (LanaPersistence) que guarda dos veces el mismo
`Expense` a través del `CoreDataExpenseStore` real y confirma que la
segunda escritura sí corrige `payer`/`split` — el nivel donde el bug
original vivía y donde el test en memoria no lo veía.

Aparte, en la misma sesión de pruebas el usuario reportó no encontrar cómo
invitar a alguien a una lista compartida ("veo que hay 3 puntos... no
funciona, no veo la forma de compartir"): el botón de compartir en
`SharedListDetailView` estaba en `ToolbarItem(placement: .secondaryAction)`,
que en iOS 26 colapsa en un menú "..." — y ahí solo se mostraba un ícono sin
texto, no legible como "invitar". Se movió a `.primaryAction` junto al
botón de `+`, con `Label("Invitar", systemImage: "person.badge.plus")` en
vez de solo el ícono.

## Consecuencias

**Bueno:**

- Editar quién pagó y cómo se divide un gasto compartido funciona de
  verdad, verificado contra el store real (Core Data), no solo contra un
  fake que no comparte la semántica de corrección por eventos.
- El botón de invitar es descubrible sin depurar un menú colapsado.

**Malo / a vigilar:**

- `InMemoryExpenseStore` sigue sin simular corrección real por eventos —
  cualquier prueba que dependa de él para verificar semántica de
  `ExpenseCorrected` puede volver a dar un falso positivo. Si se necesita
  cubrir esa semántica desde una feature sin arrastrar Core Data, vale la
  pena que `InMemoryExpenseStore` aplique correcciones como lo hace
  `LedgerFold` en vez de sobreescribir por id.
- Este bug estuvo presente desde ADR-0022 sin que ningún test lo
  detectara — la lección concreta es que un test verde contra un fake no
  certifica un flujo que depende del modelo real de eventos.

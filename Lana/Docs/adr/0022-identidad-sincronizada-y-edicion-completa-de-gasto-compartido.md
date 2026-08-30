# ADR-0022: Identidad de participante sincronizada por iCloud privado, y edición completa de pagador/split

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

ADR-0021 resolvió que un gasto compartido debía mostrar en el Dashboard
personal la parte real de quien mira, no el total — marcando localmente
(`UserDefaults`) cuál participante es "yo". Probado en el iPhone real, el
usuario pidió dos cosas más:

1. "Necesito que esa marca se sincronice." Al preguntarle qué quería decir
   exactamente, confirmó que quiere que sobreviva entre **sus propios**
   dispositivos (iPhone + iPad, o una reinstalación) — no que la elección de
   una persona la vea la otra. Eso último sería resolver identidad real de
   `CKShare`, que ADR-0017 deja pendiente a propósito y sigue fuera de
   alcance aquí.
2. "En los detalles de los gastos compartidos, no puedo editar cómo se
   divide la cuenta y quién pagó." La sesión anterior wireó "tocar un gasto
   para editarlo" reusando el editor genérico de Dashboard
   (`EditExpenseModel`/`EditExpenseView`, mismo patrón que ya usa Cards) —
   pero ese editor no tiene campo de pagador ni de regla de división, porque
   vive en `DashboardFeature`, que no conoce el roster de una lista
   compartida.

## Decisión

**1. La identidad vive en Core Data, en la zona privada, sin relación con
`CDSharedList`.**

Entidad nueva, `CDSharedListViewerPreference` (`sharedListID`,
`viewerParticipantID`). Sin relación con `CDSharedList` a propósito: si la
tuviera, `container.share(_:to:)` la arrastraría al mismo grafo de objetos
que se mueve a la zona compartida al invitar (documentado en
`CDSharedList.swift`) — viajaría al otro participante, justo lo que no se
quiere. Sin relación, sincroniza solo entre los dispositivos del propio
usuario vía su CloudKit privado (mismo mecanismo que ya sincroniza el resto
de los datos personales, ADR-0004/ADR-0020).

`SharedListStore` (protocolo, `LanaCore`) gana
`viewerParticipantID(for:) async throws -> ParticipantID?` y
`setViewerParticipantID(_:for:) async throws` — ahora async, a diferencia de
la versión síncrona de ADR-0021 sobre `UserDefaults`. Eso obligó a cambiar
`Expense.personalAmount(userDefaults:)` a
`personalAmount(viewerIdentities: [SharedListID: ParticipantID])`: un
diccionario cacheado, porque `monthTotals`/`categoryTotals`/
`paymentMethodTotals` en `DashboardModel`/`CategoryDetailModel`/
`PaymentMethodDetailModel` son computed properties síncronas que no pueden
volverse async solo por esto. `DashboardModel.loadViewerIdentities(for:from:)`
(static, reusada por los 3 modelos) resuelve una sola vez por `load()`, y
solo para las listas realmente presentes en los gastos cargados.

El tipo `SharedListViewerIdentity` (`UserDefaults`) de ADR-0021 se borró por
completo, junto con su test — reemplazado enteramente por el store real.
`needsViewerPrompt` se recalcula en cada `onAppear()` (antes, una sola vez
en `init`): si el usuario ya marcó su identidad en otro de sus dispositivos,
el prompt deja de pedirse solo en cuanto ese dato sincroniza, sin lógica
especial — es la sincronización normal de CloudKit.

**2. Editar un gasto compartido se queda dentro de `SharedFeature`, con la
UI que ya existía para capturarlo.**

En vez de enseñarle al editor genérico de Dashboard a mostrar
pagador/split (metería conceptos de "compartido" en un componente que
Cards/Dashboard también usan para gastos personales sin esos campos),
`SharedExpenseCaptureView` — que ya tiene toda la UI de pagador + las 5
reglas de split — gana un parámetro opcional `existingExpense: Expense?`
(`nil` = capturar uno nuevo, como antes). Con un valor: el formulario se
prellena completo (incluida la regla de división y las shares, derivadas del
`SplitRule` ya guardado), el título cambia a "Editar gasto", aparece
"Borrar gasto", y `save()` llama a `SharedListDetailModel.updateExpense(id:...)`
— mismo `id` que el original, así que `ExpenseStore.save(_:)` lo trata como
corrección, no como uno nuevo (el mismo mecanismo que ya usa
`EditExpenseModel`).

`SharedListDetailView` dejó de depender de un `onExpenseTap` inyectado desde
`ContentView` (que cruzaba a `DashboardFeature`) — tocar un gasto abre
`SharedExpenseCaptureView` en modo edición completamente dentro de
`SharedFeature`, con un `@State` local. Se revirtió el wiring cruzado
correspondiente en `ContentView.swift`. Cards conserva el suyo sin cambios:
para un gasto con tarjeta, el editor genérico sí alcanza — no tiene
pagador/split que editar.

## Consecuencias

**Bueno:**

- La identidad sobrevive entre los dispositivos del propio usuario sin que
  nadie más la vea — resuelve exactamente lo que se pidió, sin tocar la
  reconciliación de identidad real de CKShare que ADR-0017 sigue dejando
  para después.
- Editar un gasto compartido ahora es completo (monto, concepto, categoría,
  fecha, pagador, split) y borrar también existe — antes de este cambio no
  había forma de corregir quién pagó un gasto capturado con el pagador
  equivocado, un error de captura común y sin salida.
- `SharedFeature` no ganó ninguna dependencia nueva hacia `DashboardFeature`
  ni al revés — la edición completa vive donde ya vivía el dominio que la
  necesita.

**Malo / a vigilar:**

- Al editar un gasto con split `.proportional`/`.percentage`/`.exactAmounts`,
  lo que se precarga son las fracciones/montos ya **resueltos** que quedaron
  congelados en el evento (ADR-0007), no los números crudos que se hayan
  escrito la primera vez. Sigue siendo editable y correcto, pero si
  originalmente se escribieron ingresos como "20000"/"15000", al reabrir se
  ven como "0.5714"/"0.4286" — puede desconcertar si no se explica.
- `personalAmount` sigue sin distinguir "todavía no hay identidad marcada"
  de "el participante fue removido del roster" (misma limitación que
  ADR-0021 ya dejaba anotada, no resuelta aquí).
- Cada modelo del Dashboard (`DashboardModel`/`CategoryDetailModel`/
  `PaymentMethodDetailModel`) ahora depende también de `SharedListStore` y
  hace una resolución async extra en su `load()` — un costo pequeño pero
  real en cada carga de mes/categoría/forma de pago, incluso para meses sin
  ningún gasto compartido (el `Set` de `sharedListID`s queda vacío y el
  loop no itera nada, pero la llamada a `loadViewerIdentities` sigue
  ocurriendo).

# ADR-0017: `SharedListStore`, roster plano en `CDSharedList`, y G3 (CKShare real) pendiente

- **Estado:** Aceptada
- **Fecha:** 2026-08-27

## Contexto

Fase 8 del plan. El dominio ya estaba completo y probado desde antes de este
bloque: `SplitRule` (5 reglas + `portions(of:)`), `SharedList`, `Participant`,
`PersonLedger` (`netBalances`/`simplifiedDebts`). Los eventos `ExpenseAdded`/
`SettlementRecorded` ya cargaban `sharedListID`/`payer`/`split` desde antes,
sin que nada los consumiera. Pero `CDSharedList` (Core Data) solo tenía
`id`/`name`/`events` — cero CRUD — y `SharedFeature` era un scaffold vacío.
Nada de esto se podía usar todavía.

**El roster de participantes no tenía dónde vivir.** `SharedList.participants`
era `[ParticipantID]` — solo IDs, sin nombre para mostrar. Antes de que exista
identidad real de CKShare (G3), no hay ningún otro lugar donde guardar "quién
es quién" en una lista compartida. Se verificó que `SharedList` no se usaba
en ningún otro lado del repo (`grep` no encontró más que su propia
definición), así que se cambió su forma a `participants: [Participant]`
(roster completo) sin romper nada — cambio seguro porque no había ningún
consumidor todavía.

**Alternativas consideradas para persistir ese roster:**

- **Una entidad `CDParticipant` nueva, con relación a `CDSharedList`.**
  Descartada: antes de que G3 traiga identidad real de CKShare, un
  `Participant` es solo `{id, displayName}` local, sin relación con ninguna
  cuenta real — una entidad Core Data aparte con relación no da nada que una
  columna JSON no dé ya, y es más superficie de esquema para migrar el día
  que sí haya identidad real.
- **`participantsData`/`defaultSplitData` como columnas `Data` planas en
  `CDSharedList`** (JSON de `[Participant]`/`SplitRule`, ambos ya
  `Codable`). Elegida — mismo patrón que `Card.colorHex` (columna plana, no
  relación separada, ADR-0014).

## Decisión

`CDSharedList` gana `participantsData: Data?` y `defaultSplitData: Data?`.
`SharedListStore` (nuevo protocolo en `LanaCore`, mismo patrón que
`CardPaymentStore` de ADR-0014):

```swift
public protocol SharedListStore: Sendable {
    func save(_ list: SharedList) async throws
    func lists() async throws -> [SharedList]
    func delete(id: SharedListID) async throws
    func recordSettlement(_ settlement: SettlementRecorded) async throws
    func events() async throws -> [ExpenseEvent]
}
```

`events()` devuelve el log completo sin filtrar — `PersonLedger` necesita
correcciones/anulaciones fuera de rango para resolver bien, mismo criterio
que `CardPaymentStore.events()`. No se reimplementa por separado: ambos
protocolos piden la misma firma exacta y `CoreDataExpenseStore` conforma a
los dos a la vez (mismo actor/container) — una sola implementación en
`CoreDataCardPaymentStore.swift` satisface a ambos.

**Los gastos compartidos en sí no tienen un camino de escritura nuevo.**
`Expense` ya cargaba `sharedListID`/`payer`/`split`; un gasto compartido se
guarda por el mismo `ExpenseStore.save(_:)` de siempre. `SharedListStore`
solo cubre metadata de la lista y liquidaciones.

**Bug real encontrado y corregido al wireear esto:**
`CoreDataExpenseStore.insert(_:in:)` ya escribía `sharedListIDValue` (columna
UUID plana) pero nunca llenaba la relación real `CDEvent.sharedList ->
CDSharedList` — la que `NSPersistentCloudKitContainer.share(_:to:)` necesita
para mover los eventos junto con su lista al compartir (documentado en el
doc comment ya existente de `CDSharedList.swift`, de antes de este bloque).
Se agregó ese enlace real, con test de regresión
(`CoreDataSharedListStoreTests`).

**Tendencia de saldos** (ADR-0008 pide priorizarla sobre el número puntual):
se resuelve plegando el mismo log de eventos dos veces — ahora vs. hace 30
días, filtrando por `recordedAt` — sin dominio nuevo. Los 3 semánticos de
estado (`positive`/`warning`/`critical`) nunca pintan saldos compartidos, ni
siquiera `critical` para "debes" — ADR-0008 pide explícitamente "sin tono de
reclamo".

`SharedFeature` sigue el patrón ya establecido por `CardsFeature`: lista →
`NavigationLink` a detalle, sheets con modelos `Identifiable`, `@Bindable` en
las vistas. Captura de gasto compartido: manual, con las 5 `SplitRule` en un
segmented control y `SplitRule.portions(of:)` real para previsualizar —
todavía sin un `@Generable` de lenguaje natural para "cena 600, pagué yo,
mitad y mitad" (la skill `cloudkit-sharing` ya anticipaba que ese es un
modelo aparte, con su propio accuracy, para después).

**G3 (CKShare real) no se construye en este bloque.** Se descubrió que
`Lana.entitlements` no tiene ningún contenedor de iCloud provisionado —
`AppDependencies.live()` siempre pasa `cloudKitContainerIdentifier: nil`, un
diseño ya documentado desde antes de este bloque
(`Docs/.claude/skills/cloudkit-sharing`: "la app cae a modo local... No
revientes"). Sin un contenedor real, `NSPersistentCloudKitContainer` nunca
sincroniza con CloudKit — cualquier código de `CKShare`/
`UICloudSharingController`/aceptar invitación escrito ahora sería
enteramente no verificable, y habilitar la capability de iCloud toca
configuración de la cuenta de Apple Developer del usuario (Signing &
Capabilities, provisioning profile). Se le preguntó al usuario cómo
proceder; eligió dejar G3 en pausa por ahora. Queda documentado aquí como
el siguiente paso, no como código a medias.

**Alternativa descartada para G3:** mapear el roster directamente contra
identidad real de CKShare desde ahora. Descartada por prematura — sin
contenedor provisionado no hay forma de probarlo, y `participantsData` como
columna plana ya deja una migración limpia para el día que eso sí se
construya (leer los `CKShare.Participant` reales y reconciliarlos contra
este roster local).

## Consecuencias

**Bueno:**

- Compartir gastos es usable de punta a punta en un solo dispositivo — crear
  lista, capturar con cualquier `SplitRule`, ver saldos con tendencia,
  simplificar deudas, liquidar — todo con Core Data real, sin CloudKit.
- El bug de la relación `CDEvent.sharedList` se agarró y se corrigió antes
  de que G3 lo necesitara — de haber llegado a G3 sin esto, el fallo habría
  sido silencioso (`sharedListIDValue` seguía viéndose bien en el JSON, solo
  la relación real de Core Data estaba rota) y muy difícil de diagnosticar
  en un dispositivo real compartiendo con CloudKit.

**Malo / a vigilar:**

- `participantsData`/`defaultSplitData` no son consultables con
  `NSPredicate` (son JSON opaco) — cualquier filtro futuro por participante
  a nivel de Core Data necesita decodificar todas las filas primero. Para el
  volumen de una app de gastos personales esto no importa hoy; si algún día
  se necesita filtrar server-side o con miles de listas, revisar esta
  decisión.
- G3 sigue sin construir. Mientras el contenedor de iCloud no esté
  provisionado, "Compartido" es una lista local — nadie puede invitar a
  nadie todavía, aunque la UI y el dominio ya estén listos para eso. El
  botón/flujo de invitar no existe aún; agregar uno sin backend real sería
  peor que no tenerlo.
- Cuando G3 sí se construya, el roster de `participantsData` va a necesitar
  reconciliarse contra participantes reales de CKShare — probablemente el
  `Participant.id` local deje de ser la fuente de verdad de identidad y pase
  a ser solo un alias local para un `CKShare.Participant.userIdentity` real.
  Ese día toca revisar si `participantsData` sigue siendo la forma correcta
  o si vale más una entidad `CDParticipant` con relación (la alternativa que
  aquí se descartó) — el volumen y la necesidad de identidad real pueden
  cambiar el cálculo.

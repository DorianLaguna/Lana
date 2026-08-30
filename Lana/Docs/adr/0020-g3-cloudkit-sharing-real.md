# ADR-0020: G3 (CloudKit sharing real) — `ShareLink`, cola de invitaciones, e indicador real de sincronización

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

ADR-0017 completó todo el dominio y CRUD local de "Compartido" en Fase 8, pero
dejó G3 (`CKShare` real) deliberadamente en pausa: sin contenedor de iCloud
provisionado, cualquier código de `CKShare` habría sido no verificable. Esa
condición ya se resolvió — el usuario agregó la capability iCloud + CloudKit
en Xcode (Signing & Capabilities), con un contenedor real
(`iCloud.com.dorianlaguna.Lana`, `Lana.entitlements`). Esto desbloquea
construir G3 completo: invitar por share sheet y aceptar invitación (incluso
con la app cerrada), tal como pide PLAN.md Fase 8.

Cuatro decisiones concretas quedaron por tomar, cada una con una alternativa
más obvia que se descartó.

## Decisión

**1. Conectar el contenedor real.** `AppDependencies.live()` ahora llama
`CoreDataExpenseStore.live(cloudKitContainerIdentifier: "iCloud.com.dorianlaguna.Lana")`
en vez de pasar `nil`. Ese helper ya existía desde antes y ya caía a `nil`
internamente si `CloudKitAvailability.hasActiveAccount` es falso — no hubo
que tocar esa lógica, solo dejar de forzar el modo local.

**Efecto real, más allá de "compartido":** con iCloud activo, a partir de
ahora *todos* los datos de Lana (no solo listas compartidas) sincronizan a
la base privada de CloudKit del usuario. Es el diseño original de ADR-0004,
bloqueado hasta hoy solo por falta de contenedor — no es un efecto
secundario indeseado, pero es un cambio de comportamiento real que vale la
pena tener presente.

**2. Invitar: `ShareLink` sobre una URL, no `UICloudSharingController`.**
`SharedListStore` (`LanaCore`, protocolo Foundation-only) gana:

```swift
func shareURL(for id: SharedListID) async throws -> URL?
```

`nil` sin cuenta de iCloud activa — no es un error, es el modo local de
siempre. La implementación real, `LanaPersistence/CoreDataSharedListSharing.swift`
(extensión de `CoreDataExpenseStore`): busca la fila `CDSharedList`,
reutiliza el share existente vía `container.fetchShares(matching:)` si ya
hay uno (evita `alreadyShared` si el usuario toca "Invitar" dos veces), si
no existe lo crea con `container.share([row], to: nil)`, fija
`share[CKShare.SystemFieldKey.title]` y `share.publicPermission = .none`
(solo por invitación, nunca un link público abierto), y lo persiste con
`container.persistUpdatedShare(_:in:)`.

*Alternativa descartada:* envolver `UICloudSharingController` (UIKit) en un
`UIViewControllerRepresentable`, presentado desde `SharedFeature`.
Descartada porque `Docs/ARCHITECTURE.md` prohíbe que una feature importe
`CloudKit`/`UIKit` directamente — solo puede depender de
`LanaCore`/`LanaDesign`. Devolver una `URL` plana desde el protocolo y usar
`ShareLink(item:)` (SwiftUI puro) en `SharedListDetailView` cumple igual
"invitar por share sheet" sin ninguna capa de wrapping nueva.

**3. Aceptar invitación: `AppDelegate` con cola de invitaciones pendientes.**
`Lana/AppDelegate.swift` (nuevo, target de la app, no un paquete) implementa
`UIApplicationDelegate.application(_:userDidAcceptCloudKitShareWith:)`,
conectado vía `@UIApplicationDelegateAdaptor` en `LanaApp.swift`.
`CoreDataExpenseStore` gana `acceptShare(_:) async throws`, deliberadamente
fuera de `SharedListStore` — ninguna feature lo necesita, solo el
`AppDelegate`, así que no hace falta meter `CloudKit` en `LanaCore` para
esto.

Problema real: `AppDependencies.live()` es async y puede no haber terminado
cuando `userDidAcceptCloudKitShareWith` dispara en frío (arranque de la app
por un tap directo en el link de invitación, app previamente cerrada). Se
resuelve con una cola simple: `AppDelegate` guarda la metadata pendiente en
un array si `store` todavía es `nil`, y `ContentView` llama
`appDelegate.attach(store:)` justo después de que `AppDependencies.live()`
termina, drenando la cola. `AppDependencies` gana
`concreteExpenseStore: CoreDataExpenseStore?` (`nil` en `.preview()`) — la
única propiedad de `AppDependencies` que expone un tipo concreto en vez de
un protocolo de `LanaCore`, documentada como de uso exclusivo de
`AppDelegate.attach`.

*Alternativa descartada:* reconciliar `Participant` contra `CKShare.Participant`
real ahora que ya existe `CKShare`. Descartada — ADR-0017 ya había dejado
esto como decisión aparte para "el día que haga falta", y este cambio no la
fuerza: `CKShare` aquí solo resuelve *sync* (que ambos dispositivos vean la
misma lista y sus eventos), separado de *quién debe a quién* (el roster
manual de `Participant`, intacto).

**4. Indicador real de sincronización, no solo disponibilidad de cuenta.**
Pedido explícito del usuario: que se note dentro de la app que su
información sí está respaldada en la nube. Se descartó basar esto solo en
`CloudKitAvailability.hasActiveAccount` — cuenta activa no implica que el
sync haya funcionado alguna vez; un entitlement mal armado o un error
silencioso dejaría el indicador mintiendo "sincronizado" sin haber subido
nada, un indicador que no refleja la realidad es peor que no tenerlo (mismo
espíritu que ADR-0008).

`LanaCore` gana `SyncStatus` (`.disabled`/`.syncing`/`.synced(lastSuccess:)`/
`.failed(lastKnownGood:)`) y el protocolo `SyncStatusReporting`. La
implementación real, `LanaPersistence/CloudSyncMonitor.swift` (actor),
escucha `NSPersistentCloudKitContainer.eventChangedNotification` de verdad
vía `NotificationCenter.default.notifications(named:)` y deriva el estado
de si el último evento reportado tuvo éxito o no. Se muestra en
`SettingsFeature`/`SettingsView`, con tono "dato, no alarma" incluso para
`.failed` (Docs/CLAUDE.md → Tono del producto).

## Consecuencias

**Bueno:**

- Todo el código de `CKShare`/`NSPersistentCloudKitContainer` (`fetchShares`,
  `share(_:to:completion:)`, `persistUpdatedShare`, `acceptShareInvitations`)
  compiló contra el SDK real (Xcode 26.4,
  `xcodebuild -scheme Lana -destination 'generic/platform=iOS Simulator' build`)
  sin necesitar ajustes de firma — se verificó, no se asumió a ciegas.
- Ninguna feature importa `CloudKit`/`UIKit` — `ShareLink`+`URL` y el
  protocolo `SharedListStore` bastan. La regla de capas de
  `Docs/ARCHITECTURE.md` queda intacta.
- El indicador de sync es honesto: si CloudKit falla en silencio, el usuario
  lo ve como "no se pudo sincronizar", no como un falso "todo bien".

**Malo / a vigilar:**

- La prueba real de punta a punta — invitar, aceptar, ver la lista
  sincronizada entre dos cuentas de iCloud distintas — sigue pendiente. No
  es verificable en simulador ni sin cuenta CloudKit real
  (Docs/.claude/skills/cloudkit-sharing). El usuario la hará con un segundo
  dispositivo (de su pareja), probablemente vía TestFlight.
- El roster de `Participant` sigue sin reconciliarse contra identidad real
  de `CKShare.Participant` — dos personas pueden compartir de verdad la
  misma lista/eventos, pero "quién es quién" en el roster sigue siendo lo
  que cada quien tecleó a mano. Si esto se vuelve confuso en el uso real
  (p. ej. el roster no coincide con quién aceptó realmente la invitación),
  esa reconciliación es la siguiente decisión a tomar — ADR-0017 ya la
  anticipa.
- `CloudSyncMonitor` reporta el estado del *contenedor completo*, no por
  lista compartida — un fallo de sync en cualquier parte de los datos del
  usuario se ve reflejado en Ajustes aunque no tenga nada que ver con
  "Compartido". Suficiente para la pregunta que el usuario pidió responder
  ("¿mi información está en la nube?"), pero no aísla el estado de una lista
  compartida en particular.

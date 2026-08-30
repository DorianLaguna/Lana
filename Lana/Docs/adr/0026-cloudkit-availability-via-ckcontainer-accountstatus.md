# ADR-0026: `CloudKitAvailability` usa `CKContainer.accountStatus()`, no `ubiquityIdentityToken`

- **Estado:** Aceptada
- **Fecha:** 2026-08-28

## Contexto

El usuario reportó, con una cuenta de iCloud activa de verdad en su
iPhone, que la app seguía diciendo "necesitas una cuenta de iCloud activa
para compartir" — sin que nada le hubiera pedido iniciar sesión. Minutos
antes, en la misma sesión de pruebas, SÍ había logrado iniciar un intento
real de compartir (el error de cuota de CloudKit de ADR-0024 solo puede
salir si la llamada a CloudKit de verdad se hizo) — la señal de
disponibilidad estaba dando resultados distintos para la misma cuenta, en
el mismo dispositivo, en la misma sesión de la app.

`CloudKitAvailability.hasActiveAccount` (desde ADR-0020) miraba
`FileManager.default.ubiquityIdentityToken != nil`. Esa es la señal
correcta para apps que usan contenedores "ubiquity" — iCloud Drive,
Documents & Data — pero `Lana.entitlements` solo declara `CloudKit` en
`com.apple.developer.icloud-services`, sin ningún
`com.apple.developer.ubiquity-container-identifiers`. `ubiquityIdentityToken`
no está documentado para depender de esa capability, pero en la práctica
resultó una señal poco confiable para una app que nunca usa el lado de
"ubiquity" de iCloud — el caso real observado.

## Decisión

`CloudKitAvailability.hasActiveAccount` pasa de propiedad síncrona a
`static func hasActiveAccount(containerIdentifier: String) async -> Bool`,
implementada con `CKContainer(identifier:).accountStatus()` — la API que
CloudKit expone específicamente para esto, evaluada contra el contenedor
real de la app en vez de una señal genérica de iCloud Drive.

Esto obligó a tres cambios en cascada, todos dentro de `LanaPersistence`:

- `CoreDataExpenseStore.live(cloudKitContainerIdentifier:)` ya era
  `async throws` — solo pasó a `await` la nueva función.
- `CoreDataExpenseStore` guarda su propio `cloudKitContainerIdentifier: String?`
  (`nil` = se decidió local-only al cargar el store) — `shareURL(for:)`
  usa ese valor guardado, sin volver a preguntarle a CloudKit. La razón:
  `NSPersistentCloudKitContainerOptions` no se puede cambiar sobre un store
  ya cargado (Docs/DATA-FLOW.md-adjacent, mismo principio que ya
  documentaba el `init`), así que aunque `shareURL` volviera a checar la
  cuenta y encontrara una activa, no habría nada distinto que hacer con
  eso — la decisión real ya quedó fija al abrir la app. Si la cuenta de
  iCloud cambia después de abrir Lana, la corrección es reabrir la app,
  no una nueva consulta a mitad de sesión.
- `CloudSyncMonitor.init()` ya no puede calcular `currentStatus`
  síncronamente — arranca en `.syncing` de forma optimista y `observe()`
  lo corrige a `.disabled` de inmediato si `accountStatus()` no es
  `.available`, antes de suscribirse a `NSPersistentCloudKitContainer.eventChangedNotification`.
  Gana un parámetro `containerIdentifier: String`, pasado desde
  `AppDependencies.live()`.

El mensaje de error cuando `shareURL` regresa `nil`
(`SharedListDetailModel.prepareShare()`) se actualizó para explicar la
causa real: "no se detectó cuenta de iCloud **cuando se abrió la app**" —
con la sugerencia concreta de cerrar y reabrir Lana si ya se inició sesión
después, en vez del genérico "necesitas una cuenta activa" que sonaba a
que nunca hubo sesión.

## Consecuencias

**Bueno:**

- La señal de disponibilidad ahora refleja el estado real de la cuenta
  para el contenedor específico de Lana, sin depender de una capability
  (`ubiquity-container-identifiers`) que la app nunca declaró ni necesita.
- El mensaje de error ya no culpa al usuario de no tener sesión iniciada
  cuando el problema real es que la detección ocurrió una sola vez, al
  abrir la app.

**Malo / a vigilar:**

- La disponibilidad de CloudKit se sigue decidiendo **una sola vez, al
  abrir la app** — si el usuario inicia sesión en iCloud con Lana ya
  abierta, tiene que cerrarla y reabrirla para que la sincronización se
  active. Esto no es nuevo (ya era así con `ubiquityIdentityToken`), pero
  ahora es más visible porque el mensaje de error lo dice explícitamente.
  Si esto sigue generando confusión, la solución real sería reconstruir el
  `NSPersistentCloudKitContainer` cuando cambia el estado de la cuenta en
  caliente (vía `CKAccountChanged` notification) — no se hizo aquí, es un
  cambio de arquitectura más grande que el bug reportado no exigía.
- No se pudo reproducir el bug original localmente (requiere un
  dispositivo físico con cuenta de iCloud real) — el fix se basa en
  entender la causa (la señal correcta para el tipo de entitlement que
  esta app declara) y en que `CKContainer.accountStatus()` es la API que
  Apple documenta para exactamente este propósito, no en repetir el
  síntoma y confirmar que desapareció. Queda pendiente que el usuario lo
  confirme en su dispositivo.

# Lana — Plan de desarrollo

> Nombre de trabajo. Verifica disponibilidad en App Store Connect antes de fijarlo.

Tracker de gastos para iOS con parseo en lenguaje natural 100% on-device,
gastos compartidos con saldos, multi-moneda y consultas en lenguaje natural.
Sin backend propio y sin suscripción.

**El objetivo real del producto:** que su dueño se haga el hábito de registrar
gastos. Abandonó otros sistemas porque capturar y categorizar se sentía tedioso.
Cada decisión de diseño se mide contra eso.

---

## 1. Decisiones tomadas

| Tema | Decisión | ADR |
|---|---|---|
| Plataforma | iOS nativo, SwiftUI, iOS 26+ | — |
| Parseo | `FoundationModels` + validación por regex | 0002 |
| Evaluación del parser | Golden set con umbrales de accuracy | 0003 |
| Persistencia | Core Data + `NSPersistentCloudKitContainer` | 0004 |
| Compartir | `CKShare` con zona por lista | 0004 |
| Modelo de datos | Eventos append-only, saldos derivados | 0005 |
| Personalización | Seis pares de color curados | 0006 |
| Split proporcional | Ratio congelado en el evento | 0007 |
| Proyección | Solo cuenta compromisos con fecha | 0008 |
| Apple Pay | App Intent + Shortcuts, no API | 0009 |
| Subcategorías | Abiertas, autogeneradas, opcionales | 0011 |
| Aprendizaje | Correcciones inyectadas como vocabulario | 0012 |
| Tickets | OCR con Vision, no modelo multimodal | 0010 |
| Tarjetas (persistencia) | Entidad Core Data plana, no evento; mismo contenedor | 0014 |
| Voz | Speech framework on-device, parada manual, alimenta el mismo parser | 0015 |
| Registro manual | Formulario sin parser, secundario al micrófono | 0035 |
| Estadísticas | Agregación en `LanaCore`, vista anual dentro del Dashboard | 0036 |
| Regla de presupuesto | La elige el usuario; el modelo etiqueta sin ver montos | 0037 |
| Consultas | Seis tools deterministas; el modelo elige y narra, no calcula | 0038 |
| Disponible | Periodo anclado al sueldo; saldo derivado de lo registrado | 0039 |
| Categorías de ingreso | Catálogo propio de ocho, asignadas a mano, no por el parser | 0040 |
| Monetización | Freemium con unlock único (StoreKit 2) | — |
| Android | Fuera de alcance, permanentemente | 0004 |

---

## 2. Alcance

### v1.0
- Captura por texto en lenguaje natural
- **Captura por voz on-device** (decisión 2026-08-26, ADR-0015) — otra
  forma de producir texto, alimenta el mismo parser
- **Registro manual** (decisión 2026-09-07, ADR-0035) — el `+` del Dashboard
  abre el mismo formulario de editar, en blanco. No pasa por el parser; es la
  salida cuando dictar no es opción o Apple Intelligence no está disponible.
  Secundario a propósito: el micrófono sigue siendo el camino principal
- Parseo a `{monto, concepto, categoría, fecha}`
- Corrección manual de cualquier campo, con aprendizaje por ejemplos
- **Ingresos** además de gastos, **con categoría propia** (decisión 2026-09-08,
  ADR-0040) — ocho categorías aparte de las de gasto, elegidas a mano
- **Multi-moneda** con tasa histórica por transacción
- **Método de pago** por transacción (efectivo, débito, crédito, transferencia)
- **Tarjetas** con límite, día de corte y fecha límite; deuda por tarjeta
- **Proyección de quincena**: cuánto queda disponible después de compromisos
- **Captura por Apple Pay** vía App Intent + Shortcuts
- **Escaneo de tickets** con OCR, miniatura adjunta, un gasto por ticket
- Categorías personalizadas (nombre e ícono; el color lo da el tema)
- Dashboard mensual con desglose y navegación entre meses
- Presupuesto mensual por categoría
- **Listas compartidas con split y saldos** — quién pagó, con qué pagó, cómo se
  divide (incluido **proporcional al ingreso**), quién debe a quién, liquidaciones
- **Consultas en lenguaje natural** sobre los propios datos
- **Seis temas de color**
- Sync entre devices del mismo usuario

### Fuera de v1.0
Widgets, exportación CSV, presupuestos compartidos, meses a plazos (MSI),
ciclos de corte de saldos compartidos, desglose automático de tickets por
renglón, comprobantes fiscales.

> Nota de decisión: se recomendó dejar la UI de split para v1.1 y lanzar en ~6
> semanas para empezar el hábito antes. Se decidió incluirla completa en v1.0
> de forma consciente. El costo es ~2 meses adicionales de calendario.

---

## 3. Arquitectura

Detalle y reglas de dependencia en `Docs/ARCHITECTURE.md`.

```
Lana/
├── App/                          # Composición y ciclo de vida
├── Packages/
│   ├── LanaCore/                 # Dominio puro. Solo Foundation.
│   │   ├── Models/               # Money, Currency, Event, Card, PaymentMethod,
│   │   │                         #   Participant, SplitRule
│   │   ├── Ledger/               # Plegado de eventos → saldos (personas y tarjetas)
│   │   ├── Projection/           # Disponible por quincena
│   │   └── Protocols/            # ExpenseStore, ExpenseParsing, InsightQuerying…
│   ├── LanaParsing/              # FoundationModels
│   ├── LanaSpeech/               # Speech framework, transcripción on-device
│   ├── LanaPersistence/          # Core Data + CloudKit + CKShare
│   ├── LanaPurchases/            # StoreKit 2
│   ├── LanaDesign/               # Tokens, temas, componentes
│   └── LanaFeatures/
│       ├── EntryFeature/
│       ├── DashboardFeature/
│       ├── BudgetsFeature/
│       ├── SharedFeature/
│       ├── CardsFeature/
│       ├── InsightsFeature/
│       └── SettingsFeature/
├── Docs/
├── Tests/Fixtures/
└── .claude/
```

**Regla de oro:** `LanaCore` no importa nada más que `Foundation`. Las features no
se conocen entre sí ni conocen implementaciones concretas.

---

## 4. Fases

Cada fase cierra con algo que corre.

### Fase 0 — Cimientos · ✅ COMPLETADA 2026-08-26
- [x] Proyecto Xcode + paquetes locales con dependencias declaradas
- [x] SwiftLint + SwiftFormat + Swift 6 strict concurrency
- [x] CI en GitHub Actions
- [x] `.claude/` configurado

**Cierre:** `xcodebuild build` verde en CI, más `swift test` verde en los 12
paquetes locales. El target `LanaTests` (a nivel de app) se creó pero se dejó
sin enlazar a propósito — no hay nada real que probar ahí hasta que existan
ViewModels (Fase 5+). Ahí se retoma y el job de CI vuelve a ser `test`.

### Fase 0.5 — Spike del parser · ✅ COMPLETADA 2026-08-24

Resultados con 20 frases reales en iPhone físico:

| Métrica | Resultado |
|---|---|
| Conteo | 100% |
| Monto | 100% |
| Categoría (base) | 75% |
| Categoría (con aprendizaje) | 90% |

Confirmado: el modelo entiende español mexicano coloquial. El `AmountValidator`
es obligatorio — se observaron 45→45000 y suma de dos gastos en uno.
Hallazgos en ADR-0011, 0012, 0013 y en la skill `foundation-models`.

### Fase 1 — Dominio · ✅ COMPLETADA 2026-08-26
Esta fase define lo que no se puede cambiar después. Tómate el tiempo.

- [x] `Money`: `Decimal` + moneda. **Nunca `Double`.**
- [x] `Currency` con tasa histórica por transacción
- [x] Eventos inmutables: `ExpenseAdded`, `IncomeAdded`, `ExpenseCorrected`,
      `ExpenseVoided`, `SettlementRecorded`
- [x] `PaymentMethod`: efectivo, débito, crédito, transferencia
- [x] `Card`: alias, últimos 4, límite, día de corte, fecha límite.
      **Nunca el número completo, CVV ni vencimiento.**
- [x] `SplitRule`: iguales, solo el pagador, **proporcional con shares congelados**,
      porcentaje, montos exactos
- [x] `Participant` y `SharedList`
- [x] `Ledger`: pliega eventos → saldos. Puro, sin dependencias, muy probado.
- [x] **Dos ledgers independientes**: deuda con tarjetas y deuda con personas.
      Nunca se suman ni se mezclan.
- [x] Ciclos de corte: saldo actual vs saldo al corte por tarjeta
- [x] `Projection`: disponible por quincena. **Solo cuenta lo que tiene fecha.**
- [x] Simplificación de deudas para 3+ personas
- [x] Protocolos: `ExpenseStore`, `ExpenseParsing`, `InsightQuerying`, `PurchaseGating`
- [x] Implementaciones en memoria para tests y previews

**Cierre:** `PersonLedger`/`CardLedger` calculan saldos correctos en escenarios
de 2 y 4 personas con correcciones, anulaciones y liquidaciones de por medio,
incluyendo un test explícito de que el orden de los eventos no cambia el
resultado (ADR-0005). 34 tests en `LanaCore`, todo vía `swift test`, sin
simulador. `ExpenseParsing`/`InsightQuerying` llevan tipos mínimos
(`ParseResult`, `LedgerTool`) suficientes para que el protocolo compile — su
forma real se define en Fase 3 y Fase 9 respectivamente.

Se agregó un sexto evento, `CardPaymentRecorded`, que estaba documentado en
`Docs/DATA-FLOW.md` pero faltaba en este checklist — pagar la tarjeta no es un
gasto y hacía falta antes de fijar el esquema de Core Data en Fase 2.
`CardLedger.outstandingStatementBalance` neta los pagos contra lo facturado.

Nota de implementación: un literal fraccionario asignado a `Decimal` pasa por
`Double` antes de convertirse (`1234.56` puede dar `1234.5599999999997952`) —
documentado en el doc comment de `Money`. Construir montos exactos con
`Decimal(string:)`, nunca con el literal directo.

### Fase 2 — Persistencia · ✅ COMPLETADA 2026-08-26
- [x] Core Data + `NSPersistentCloudKitContainer`
- [x] Zona privada para lo personal, **zona propia por lista compartida**
- [x] Modelo compatible con CloudKit (todo con default u opcional)
- [x] Fallback a local si no hay iCloud
- [x] Round-trips y migraciones probadas

**Cierre:** `CoreDataExpenseStore` (`LanaPersistence`) implementa `ExpenseStore`
guardando cada `save`/`delete` como un `ExpenseEvent` nuevo (nunca muta nada,
ADR-0005) y leyendo vía `ExpenseProjection`. 9 tests cubren round-trip,
corrección (guardar dos veces el mismo id), anulación, filtro por rango, e
ingreso sin categoría — incluyendo persistir de verdad en disco entre dos
instancias distintas del store. El esquema tiene `CDSharedList` ←→ `CDEvent`
como relación (Docs/.claude/skills/cloudkit-sharing): compartir una lista via
`NSPersistentCloudKitContainer.share(_:to:)` mueve automáticamente sus
eventos a la zona nueva del share, porque son parte del mismo grafo de
objetos — verificado que el grafo está bien armado, no que el share real
funciona (eso requiere cuenta de iCloud y dos devices físicos, ADR-0004,
fuera de alcance hasta Fase 8).

Dos decisiones de implementación que vale la pena dejar anotadas:
- El modelo de Core Data se construye en código
  (`LanaManagedObjectModel.swift`), no con un `.xcdatamodeld` editado en
  Xcode: SwiftPM copia ese archivo tal cual pero no lo compila a `.momd` —
  eso requiere `momc`, que solo corre como build phase de Xcode, y
  `swift test --package-path Packages/LanaPersistence` (Docs/CLAUDE.md) tiene
  que funcionar standalone.
- "Migraciones probadas" hoy significa que la infraestructura está lista
  (`shouldMigrateStoreAutomatically`/`shouldInferMappingModelAutomatically`)
  y que las columnas son todas opcionales — no que se ejecutó una migración
  real, porque todavía no existe una v2 del esquema contra la cual migrar.

### Fase 3 — Parser · ⏳ EN PROGRESO 2026-08-26 — ver cierre
- [x] `ParsedTransaction` con `@Generable` y `@Guide` por campo
- [x] Distinguir ingreso de gasto
- [x] Moneda explícita cuando el texto la menciona
- [x] Método de pago y tarjeta desde el texto ("con la Nu", "en efectivo")
- [x] `@Generable` aparte para modo compartido (pagador + regla de división)
- [x] `AmountValidator` por regex; **su resultado gana sobre el modelo**
- [x] Los 4 casos de `availability` mapeados (`ParserAvailability`) — la UI
      distinta para cada uno es trabajo de Fase 5 (pantalla de captura)
- [x] `prewarm()` expuesto — llamarlo al abrir la captura es trabajo de Fase 5
- [x] Subcategorías con fuzzy match y vocabulario que crece (ADR-0011)
- [x] Aprendizaje: correcciones como pares término→categoría (ADR-0012)
- [x] **Cero cifras en las instrucciones** (ADR-0013) — probado
- [x] Filtro determinista: descartar gastos con monto ≤ 0
- [ ] Golden set ≥80 frases propias — sigue en 20, ver nota
- [x] Suite de accuracy por campo: conteo, monto, categoría, subcategoría
      (`swift run parser-eval Tests/Fixtures/golden-set.json`, dentro de
      `Packages/LanaParsing`)

**Cierre real, medido contra el golden set de 20 casos × 3 corridas (Apple
Intelligence disponible en esta máquina, no simulado):**

| Campo | Resultado | Umbral | ¿Pasa? |
|---|---|---|---|
| Monto | 98.4% (62/63) | 90% | ✓ |
| Conteo | 98.3% (59/60) | 95% | ✓ |
| Categoría | 68.3% (43/63) | 80% | ✗ |
| Subcategoría | 43.5% (10/23) | 60% | ✗ |

**Monto no se negocia y ya pasa.** En el camino se corrigió un bug real en
`AmountValidator`: números de 4+ dígitos sin coma de miles ("1000") se
partían mal por un regex mal armado — eso, no el modelo, causaba la mayoría
de las fallas de monto iniciales (85.7% → 98.4% con el fix).

**Categoría y subcategoría no llegan al umbral sin aprendizaje.** El
`@Guide` se afinó en 3 rondas (comida/despensa quedó particularmente
confuso: "dulces", "mangos enchilados", "Boing" se clasifican como `comida`
en vez de `despensa` de forma consistente) y subió de 41.3% a 68.3%, pero
se estancó ahí — más ajustes al guide sobre el mismo golden set de 20 casos
arriesgan sobreajustar sin generalizar. El baseline original del spike
(Fase 0.5) también fue 75% *sin aprendizaje* y solo llegó a 90% *con*
8 correcciones reales (ADR-0012) — el mecanismo de aprendizaje existe y está
probado (`CorrectionVocabulary`), pero no hay uso real todavía que lo
alimente. Varios de los fallos de categoría/subcategoría (bocina→ocio,
acampar→ocio, chicles→despensa, gimnasio→personal) son exactamente el
patrón que ADR-0012 documenta como resuelto por aprendizaje, no por prompt.

**Pendiente, no bloqueante para seguir de fase:** el golden set sigue en 20
casos reales (el checklist pide ≥80) — no se generaron frases sintéticas
para no distorsionar la métrica (ver conversación 2026-08-26). Crece con uso
real, como ya dice la nota del archivo.

### Fase 4 — Sistema de diseño · ✅ COMPLETADA 2026-08-26
- [x] Tokens semánticos, escala de espaciado, tipografía
- [x] Los seis temas con contraste verificado en claro y oscuro
- [x] Rampa de 8 colores de categoría derivada del tema
- [x] Componentes base: fila de transacción, tarjeta, campo de entrada, estados vacíos
- [x] `#Preview` que itera los seis temas

**Cierre:** `LanaColors` (accent/highlight/categoryRamp/surface/texto/
semánticos), `Space` (4/8/16/24/32/48pt), `LanaTextStyle` (ligado a Dynamic
Type) y 4 componentes (`TransactionRow`, `LanaCard`, `LanaTextField`,
`EmptyStateView`), cada uno con `#Preview` iterando los 6 temas. 11 tests en
`LanaDesign` verifican contraste WCAG real (≥4.5:1, los 6 primarios y
secundarios en claro y oscuro, más los semánticos fijos) y que la rampa de
8 colores de categoría queda separada por 45° — sin necesitar un contexto de
renderizado.

Los 6 hex del ADR-0006 no cumplían 4.5:1 en ambas apariencias a la vez con
el mismo valor (matemáticamente casi imposible: un color no puede ser
oscuro contra blanco y claro contra negro simultáneamente). Cada tema quedó
con una variante clara y una oscura, ajustando solo luminosidad y
conservando tono y saturación — la identidad de marca se mantiene, el hex
original se conservó en el modo donde ya cumplía. `LanaDesign` no está
conectado a la app todavía (`ContentView.swift` sigue siendo el placeholder
de Fase 0) — eso empieza en Fase 5.

### Fase 5 — Captura · ✅ COMPLETADA 2026-08-26
- [x] Entrada, preview del parseo, confirmar
- [x] Edición inline antes de guardar
- [x] **Guardar nunca se bloquea** — lo ambiguo entra con `needsReview`
- [x] Onboarding para Apple Intelligence no disponible

**Cierre:** `EntryModel` (`@MainActor @Observable`, sin SwiftUI) implementa
abrir (`onAppear` revisa disponibilidad y precalienta) → escribir (`submit`
parsea y llena `drafts`, editables inline vía `DraftCard`) → confirmar
(`confirm` guarda todos los borradores). `EntryView` no decide nada, solo
refleja `stage`. Los 4 casos de `ParsingAvailability` tienen su propia
pantalla en `AvailabilityOnboardingView`. 9 tests en `EntryModel` cubren el
flujo completo, incluido uno explícito de que confirmar con
`needsReview: true` sí guarda (no bloquea) y otro de que editar un borrador
antes de confirmar persiste la edición, no el original del parser.

Tres brechas reales entre fases anteriores, encontradas al construir esta:
- `ParsingAvailability` (los 4 casos) vivía en `LanaParsing`, pero las
  features solo pueden depender de `LanaCore`/`LanaDesign` — se movió el
  tipo a `LanaCore` y `ExpenseParsing` ahora expone `availability` y
  `prewarm()` en el protocolo.
- `ParseResult` no distinguía ingreso de gasto (`kind`) pese a que el
  parser sí lo extrae desde Fase 3 — se perdía en el mapeo.
- `subcategory` llegaba hasta `ParseResult` pero nunca a `Expense` ni a los
  eventos (`ExpenseAdded`/`ExpenseCorrected`) — se habría perdido al
  guardar. Se propagó de punta a punta y se agregó un test de round-trip.

`EntryFeature` no está conectado al target de la app todavía —
`ContentView.swift` sigue siendo el placeholder de Fase 0, y la instancia
real de `FoundationModelsExpenseParsing` + `CoreDataExpenseStore` (en vez de
las de memoria usadas en tests y `#Preview`) se conecta cuando exista la
composición de la app (`App/AppDependencies.swift`, Docs/ARCHITECTURE.md) —
no es una fase propia en este plan todavía.

### Fase 6 — Dashboard · ✅ COMPLETADA 2026-08-26
- [x] Lista agrupada por día, con ingresos y gastos
- [x] Total del mes, desglose por categoría (Swift Charts)
- [x] Navegación entre meses
- [x] Bandeja de `needsReview`

**Cierre:** `DashboardModel` (`@MainActor @Observable`) carga el mes vigente,
agrupa por día, separa totales por moneda (nunca los suma entre sí —
Docs/CONVENTIONS.md), y expone `needsReviewItems`. `DashboardView` usa
`Charts` (`CategoryBreakdownChart`) para el desglose, con el color de cada
categoría derivado de un hash estable (no del `Hashable` de Swift, que
cambia de semilla en cada corrida) para no depender de `LanaParsing`. 7
tests cubren agrupación, navegación entre meses, separación de monedas y el
filtro de revisión.

**Además de la fase, y a petición explícita del usuario ("ya quiero empezar
a ver algo en mi cel"), se conectó todo al target de la app** — trabajo que
no es una fase propia en este plan:
- `AppDependencies` (`App/`, Docs/ARCHITECTURE.md → Composición): el único
  lugar que conoce las implementaciones concretas. `.live()` usa
  `FoundationModelsExpenseParsing` + `CoreDataExpenseStore` **local, sin
  CloudKit** — `Lana.entitlements` todavía no tiene un contenedor de iCloud
  provisionado (`icloud-container-identifiers` vacío), así que forzar uno
  habría reventado (visto en Fase 2). `purchases` usa `InMemoryPurchaseGating`
  como stand-in hasta Fase 10 (`LanaPurchases` real, StoreKit 2).
- `ContentView` arma `AppDependencies` de forma async y muestra un
  `TabView` (Captura / Dashboard) una vez lista.
- Se borraron `Persistence.swift` y el `Lana.xcdatamodeld` de la plantilla
  de Xcode — código muerto desde que existe `LanaPersistence.CoreDataExpenseStore`.
- Verificado corriendo la app de verdad en el iPhone físico conectado
  (`xcrun devicectl`): instala, lanza y no crashea.

Pendiente para cuando el usuario provisiones un contenedor de iCloud en
Xcode (Signing & Capabilities): pasar `AppDependencies.live()` a detectar
`CloudKitAvailability.hasActiveAccount` y usar el identificador real.

### Fase 6.5 — Voz, Tarjetas y Ajustes · ✅ COMPLETADA — ver nota de auditoría 2026-08-27
Nace de un rediseño de UI/UX pedido explícitamente por el usuario (mockup
en Claude Design, aprobado 2026-08-26): Captura se integra al Dashboard
(sin tab propio) detrás de un FAB de micrófono, y aparecen dos secciones
nuevas que no tenían fase propia — Tarjetas y Ajustes.

- [x] `SpeechTranscribing` (`LanaCore`) + paquete `LanaSpeech` (Speech
      framework, on-device, parada manual) — ADR-0015
- [x] Captura por voz integrada al flujo de `EntryFeature`: escuchar →
      transcribir → el mismo `submit()`/parseo/revisión que ya existía
- [x] Se cierra un hueco de Fase 3: `EntryModel` ahora sí llama
      `vocabularyStore.record(...)` cuando el usuario corrige la categoría
      (ADR-0012 quedaba construido pero nunca disparado) — `EntryModel.swift:266`
- [x] `CardStore` (`LanaCore`) + `CDCard` (`LanaPersistence`, misma
      instancia/contenedor que `CoreDataExpenseStore`) — ADR-0014
- [x] `CorrectionVocabularyStore` se mueve a `LanaCore`
      (`category: String`, ya no `ExpenseCategory`) y gana persistencia
      real (`CDVocabularyEntry`) + `delete(term:)`/`deleteAll()`
- [x] `CardsFeature`: lista, alta/edición, detalle con gastos y desglose
      por categoría de esa tarjeta. Deuda = cargos de crédito en el ciclo
      de corte vigente — y de hecho **ya incluye registrar pagos**
      (`AddCardPaymentView`/`CardDetailModel.recordPayment`), adelantado de
      Fase 7.5
- [x] `SettingsFeature`: selector de los 6 temas (persistido), vocabulario
      aprendido visible con borrado individual y total
- [x] Dashboard: dos tarjetas de estadística (Gastado/Ingresos) en vez de
      una sola; desglose por categoría tappable → detalle con transacciones
      de esa categoría (más un segundo desglose por forma de pago, no
      pedido en el checklist original)
- [x] `MainTabView`: 4 tabs (Dashboard/Tarjetas/**Compartido**/Ajustes —
      Compartido se adelantó de Fase 8 a petición explícita del usuario),
      tema ya no fijo en Cobalto

**Cierre real (auditoría 2026-08-27):** esta fase se dio por pendiente en
el plan durante un tiempo mientras ya estaba terminada en el código —el
plan no se actualizó en el momento. Verificado leyendo cada archivo, no
solo su existencia. `outstandingStatementBalance` (saldo al corte neto de
pagos) también quedó resuelto aquí vía `CardPaymentStore`/
`CoreDataCardPaymentStore`, adelantando esa parte de Fase 7.5.

### Fase 7 — Presupuestos · 2-3 días
- [ ] CRUD mensual por categoría, con avance
- [ ] Presentación como dato, sin tono de regaño

**Estado (auditoría 2026-08-27):** `BudgetsFeature` sigue siendo un
scaffold puro (`enum BudgetsFeature { static let moduleName }`), sin
importar en la app real. Nada hecho todavía.

### Fase 7.5 — Tarjetas y proyección · 5-7 días ← el diferenciador real
- [x] CRUD de tarjetas con corte y fecha límite — hecho en Fase 6.5
- [x] Deuda por tarjeta del ciclo vigente — hecho en Fase 6.5
- [x] Saldo al corte neto de pagos (`outstandingStatementBalance`) —
      hecho en Fase 6.5 vía `CardPaymentStore`
- [x] Al registrar con tarjeta, mostrar a qué corte cae y cuándo se paga
      — cubierto por `UpcomingCardPaymentsSection`/`UpcomingCardPaymentsModel`
      en el Dashboard
- [ ] Proyección de quincena: ingresos − compromisos con fecha = disponible.
      **`Projection.swift` (`LanaCore`) ya existe y está probado**
      (`available(currentBalance:commitments:through:)`), pero no se llama
      desde ninguna feature todavía — falta la UI que lo conecte
- [ ] Cuentas por cobrar en sección aparte, **nunca sumadas al disponible**
- [x] App Intent "Agregar transacción" — `AddTransactionIntent`
      (`Lana/Intents/AddTransactionIntent.swift`), match de tarjeta por
      heurística de texto contra el nombre que da el trigger de Wallet
      (`Card.bestMatch`, `LanaCore`, probado), categoría sugerida vía el
      parser existente cuando el modelo está disponible. Detalle de
      implementación en ADR-0019. **Falta:** la guía de configuración de
      Shortcuts dentro del onboarding — sin ella la función no existe para
      la mayoría de los usuarios (ADR-0009)
- [ ] **Todo lo capturado por Apple Pay entra con `needsReview`**
- [ ] Alerta de tarjeta cerca del límite, como dato y no como reproche

### Fase 7.8 — Escaneo de tickets · 3-4 días
- [ ] `VNDocumentCameraViewController` para capturar con recorte automático
- [ ] OCR con Vision → texto → el `ExpenseParsing` que ya existe
- [ ] Heurística de total: descartar SUBTOTAL, IVA, CAMBIO, PROPINA SUGERIDA
- [ ] **Validar el monto del modelo contra los montos que el OCR sí encontró**
- [ ] Miniatura JPEG, lado mayor 1000px, objetivo <150 KB, binario externo
- [ ] Confirmación con la miniatura al lado de los campos parseados
- [ ] **Todo entra con `needsReview`**

### Fase 8 — Compartir · 6-8 días ← la fase más riesgosa
- [x] Crear lista, generar `CKShare`, invitar por share sheet — `ShareLink`
      sobre `SharedListStore.shareURL(for:)`, ADR-0020
- [x] Aceptar invitación, incluyendo con la app cerrada — `AppDelegate` +
      cola de invitaciones pendientes, ADR-0020
- [x] Registrar gasto con pagador y regla de división — `SharedExpenseCaptureView`
- [x] Vista de saldos: quién debe a quién, **con tendencia** además del número
      — `ParticipantBalance.Trend`, `BalancesView`
- [x] Registrar liquidación, con método de pago — `SettleUpView`
- [ ] Recordatorio suave al cruzar umbral de monto o antigüedad (configurable)
- [ ] Permisos: participantes corrigen lo propio, no lo ajeno
- [ ] Prueba real en dos devices físicos con cuentas distintas — pendiente,
      el usuario la hará con un segundo dispositivo (de su pareja),
      probablemente vía TestFlight

**Estado (2026-08-28, ADR-0020):** G3 (CloudKit sharing real) ya está
implementado y compila contra el SDK real — contenedor de iCloud
provisionado, `AppDependencies.live()` ya no fuerza modo local. Lo único
genuinamente pendiente de esta fase es la prueba real de punta a punta
entre dos cuentas de iCloud distintas (no verificable en simulador) y el
recordatorio suave de saldo, que es un ítem aparte sin relación con CKShare.
El roster de `Participant` sigue sin reconciliarse contra identidad real de
`CKShare.Participant` — deliberado, ver ADR-0017/ADR-0020.

### Fase 8.5 — Vista anual y análisis · 5-7 días

Dos superficies separadas, a las que se entra por sendos botones en el toolbar
del Dashboard: el año (estadísticas puras) y el análisis (narrado con IA).

- [x] `LanaCore/Statistics/`: `PeriodStatistics`, `AnnualStatistics`,
      `PeriodComparison`, `PeriodTotal` y `groupedByMonth`. El Dashboard y el
      detalle de tarjeta pasan a delegar ahí (ADR-0036).
- [x] Vista anual: serie de doce meses tocable, promedio, mes más caro y más
      barato, tasa de ahorro, desgloses por categoría/subcategoría/forma de
      pago, gastos hormiga, días con movimiento y las dos comparaciones (contra
      el mes anterior y contra el mismo mes del año pasado).
- [x] Regla de presupuesto: catálogo de cuatro (50/30/20, 70/20/10, 60/20/20 y
      "págate primero"), elegible desde la propia pantalla de Análisis y
      guardada en `UserDefaults`. **Cuál seguir es decisión del usuario, no una
      constante del código** — Lana recomienda, no impone.
- [x] `SpendingClassifying`: la IA etiqueta pares categoría/subcategoría como
      Necesidad/Deseo/Ahorro. **Nunca ve montos**; el código suma (`BudgetMix`).
      Las etiquetas no se persisten.
- [x] Sin ingreso registrado: solo la mezcla como % del gasto, sin metas y sin
      tramo de ahorro. Nunca se inventa un denominador.
- [x] `InsightNarrating`: resumen del mes y del año, patrones y sugerencias, a
      partir de cifras **ya calculadas**. Y la sugerencia de regla, validada
      contra el catálogo cerrado.
- [x] `InsightsFeature`: la pantalla, con su compuerta de `availability`. Sin
      Apple Intelligence no aparece; la vista anual sí, completa.

### Fase 9 — Consultas en lenguaje natural · 3-4 días
- [x] Tools deterministas: `totalPorCategoria`, `comparaMeses`, `mayoresGastos`,
      `saldoDeLista`, `deudaPorTarjeta` y `disponibleProyectado` — todas en
      `LanaCore.LedgerToolbox`, devolviendo texto ya formateado
- [x] `disponibleProyectado` sin saldo bancario: el periodo se ancla al sueldo
      (un `RecurringItem` de ingreso) y el saldo sale de lo registrado desde el
      último sueldo. La cifra **siempre** viaja con la línea que dice de qué
      está hecha. Ver ADR-0039
- [x] Sesión con tool calling (`FoundationModelsInsightQuerying`)
- [x] **El modelo no calcula, solo narra.** Nunca le pases el historial crudo.
- [x] Preguntas sugeridas para el estado vacío

### Fase 10 — Monetización · 2 días
- [ ] No consumible en App Store Connect + archivo `.storekit`
- [ ] Gate por conteo, **visible desde el primer día de uso**
- [ ] Paywall y restaurar compras

### Fase 11 — Lanzamiento · 4-5 días
- [ ] Accesibilidad: VoiceOver, Dynamic Type hasta AX3, contraste
- [ ] Modo oscuro en los seis temas
- [ ] Localización es-MX / en
- [ ] Privacy Manifest
- [ ] **Requisito de Apple Intelligence en la descripción y el primer screenshot**
- [ ] TestFlight con 5-10 personas

---

## 5. Documentación

1. **DocC** — API de cada paquete. `///` en todo lo `public`.
2. **ADRs** — el porqué de cada decisión estructural. Van en el mismo PR que el cambio.
3. **README + ARCHITECTURE + CONVENTIONS** — cómo entrarle.

---

## 6. Testing

| Capa | Qué | Cómo |
|---|---|---|
| `Ledger` | Saldos con correcciones, anulaciones, liquidaciones, 2-4 personas, split proporcional | Swift Testing. **La suite más importante del repo.** |
| `Projection` | Disponible con compromisos a fecha; por cobrar excluido | Swift Testing |
| Ciclos de corte | Un gasto antes y después del corte cae en el ciclo correcto | Swift Testing con fechas fijas |
| `Money` | Aritmética, monedas mezcladas | Swift Testing |
| `LanaParsing` | Golden set | Reporte de accuracy, no pass/fail |
| `LanaPersistence` | Round-trips, migraciones | Store en memoria |
| Features | ViewModels | Swift Testing |
| Compartir | Sync real | Manual, dos devices físicos |
| Apple Pay | Captura por Shortcuts | Manual, device físico con tarjetas reales |

---

## 7. Riesgos

| Riesgo | Mitigación |
|---|---|
| El modelo no entiende español mexicano coloquial | Fase 0.5 lo revela en 2 horas |
| Saldo compartido corrupto por sync | Modelo append-only (ADR-0005) |
| Apple degrada el modelo entre versiones | Golden set en CI y en cada beta |
| CloudKit sharing no se puede probar bien | Presupuestar dos devices físicos en Fase 8 |
| Descargas de gente sin Apple Intelligence → 1 estrella | Decirlo en descripción y primer screenshot |
| OCR falla en papel térmico decolorado | `needsReview` obligatorio; captura manual sigue siendo el camino principal |
| El trigger de Apple Pay falla o duplica | Todo entra con `needsReview`; la captura manual es el camino principal |
| Proyección con número inflado → se deja de usar | ADR-0008: solo cuenta lo que tiene fecha |
| Scope creep | La lista de "fuera de v1.0" es un contrato |
| **El hábito no arranca en 4-5 meses de desarrollo** | Apuntar gastos en Notas desde hoy; alimenta el golden set |

---

## 8. Claude Code

**Agentes**
- `swift-reviewer` — convenciones y arquitectura, antes de commit
- `design-reviewer` — jerarquía, temas, accesibilidad, fricción de uso
- `test-author` — tests con Swift Testing
- `parser-evaluator` — accuracy contra el golden set

**Skills**
- `foundation-models` — la API y sus trampas
- `theming` — tokens, los seis temas, reglas de uso
- `cloudkit-sharing` — zonas, `CKShare`, modelo de eventos
- `cards-and-cashflow` — tarjetas, cortes, proyección, Apple Pay
- `receipt-scanning` — OCR, elección del total, miniaturas
- `feature-module` — crear un módulo nuevo
- `adr-writer` — redactar un ADR

**Flujo:** rama por feature → describir la tarea apuntando al plan → `swift-reviewer`
y `design-reviewer` antes de commit → `adr-writer` si tocaste estructura.

---

## 9. Estimación

| Fase | Días |
|---|---|
| 0 — Cimientos | 1-2 |
| 0.5 — Spike | 0.5 |
| 1 — Dominio | 4-6 |
| 2 — Persistencia | 4-5 |
| 3 — Parser | 4-6 |
| 4 — Diseño | 3-4 |
| 5 — Captura | 4-5 |
| 6 — Dashboard | 4-5 |
| 6.5 — Voz, Tarjetas y Ajustes | 6-8 |
| 7 — Presupuestos | 2-3 |
| 7.5 — Tarjetas y proyección | 5-7 |
| 7.8 — Tickets | 3-4 |
| 8 — Compartir | 6-8 |
| 9 — Consultas | 3-4 |
| 10 — Monetización | 2 |
| 11 — Lanzamiento | 4-5 |
| **Total** | **~59-79 días enfocados** |

En calendario real con otras cosas encima: **5 a 7 meses**.

Costo fijo: cuenta de desarrollador, $99 USD al año. Sin costos de servidor.

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
| Monetización | Freemium con unlock único (StoreKit 2) | — |
| Android | Fuera de alcance, permanentemente | 0004 |

---

## 2. Alcance

### v1.0
- Captura por texto en lenguaje natural
- Parseo a `{monto, concepto, categoría, fecha}`
- Corrección manual de cualquier campo, con aprendizaje por ejemplos
- **Ingresos** además de gastos
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
Entrada por voz, widgets, exportación CSV, presupuestos compartidos, meses a
plazos (MSI), ciclos de corte de saldos compartidos, desglose automático de
tickets por renglón, comprobantes fiscales.

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

### Fase 0 — Cimientos · 1-2 días
- [ ] Proyecto Xcode + paquetes locales con dependencias declaradas
- [ ] SwiftLint + SwiftFormat + Swift 6 strict concurrency
- [ ] CI en GitHub Actions
- [ ] `.claude/` configurado

**Cierre:** `xcodebuild test` verde en CI.

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

### Fase 1 — Dominio · 4-6 días
Esta fase define lo que no se puede cambiar después. Tómate el tiempo.

- [ ] `Money`: `Decimal` + moneda. **Nunca `Double`.**
- [ ] `Currency` con tasa histórica por transacción
- [ ] Eventos inmutables: `ExpenseAdded`, `IncomeAdded`, `ExpenseCorrected`,
      `ExpenseVoided`, `SettlementRecorded`
- [ ] `PaymentMethod`: efectivo, débito, crédito, transferencia
- [ ] `Card`: alias, últimos 4, límite, día de corte, fecha límite.
      **Nunca el número completo, CVV ni vencimiento.**
- [ ] `SplitRule`: iguales, solo el pagador, **proporcional con shares congelados**,
      porcentaje, montos exactos
- [ ] `Participant` y `SharedList`
- [ ] `Ledger`: pliega eventos → saldos. Puro, sin dependencias, muy probado.
- [ ] **Dos ledgers independientes**: deuda con tarjetas y deuda con personas.
      Nunca se suman ni se mezclan.
- [ ] Ciclos de corte: saldo actual vs saldo al corte por tarjeta
- [ ] `Projection`: disponible por quincena. **Solo cuenta lo que tiene fecha.**
- [ ] Simplificación de deudas para 3+ personas
- [ ] Protocolos: `ExpenseStore`, `ExpenseParsing`, `InsightQuerying`, `PurchaseGating`
- [ ] Implementaciones en memoria para tests y previews

**Cierre:** el ledger calcula saldos correctos en escenarios de 2 y 4 personas con
correcciones, anulaciones y liquidaciones de por medio. Todo sin simulador.

### Fase 2 — Persistencia · 4-5 días
- [ ] Core Data + `NSPersistentCloudKitContainer`
- [ ] Zona privada para lo personal, **zona propia por lista compartida**
- [ ] Modelo compatible con CloudKit (todo con default u opcional)
- [ ] Fallback a local si no hay iCloud
- [ ] Round-trips y migraciones probadas

### Fase 3 — Parser · 4-6 días
- [ ] `ParsedTransaction` con `@Generable` y `@Guide` por campo
- [ ] Distinguir ingreso de gasto
- [ ] Moneda explícita cuando el texto la menciona
- [ ] Método de pago y tarjeta desde el texto ("con la Nu", "en efectivo")
- [ ] `@Generable` aparte para modo compartido (pagador + regla de división)
- [ ] `AmountValidator` por regex; **su resultado gana sobre el modelo**
- [ ] Los 4 casos de `availability` con UI distinta cada uno
- [ ] `prewarm()` al abrir la captura
- [ ] Subcategorías con fuzzy match y vocabulario que crece (ADR-0011)
- [ ] Aprendizaje: correcciones como pares término→categoría (ADR-0012)
- [ ] **Cero cifras en las instrucciones** (ADR-0013)
- [ ] Filtro determinista: descartar gastos con monto ≤ 0
- [ ] Golden set ≥80 frases propias
- [ ] Suite de accuracy por campo: conteo, monto, categoría, subcategoría

**Cierre:** ≥90% en monto, ≥80% en categoría. El monto no se negocia.

### Fase 4 — Sistema de diseño · 3-4 días
- [ ] Tokens semánticos, escala de espaciado, tipografía
- [ ] Los seis temas con contraste verificado en claro y oscuro
- [ ] Rampa de 8 colores de categoría derivada del tema
- [ ] Componentes base: fila de transacción, tarjeta, campo de entrada, estados vacíos
- [ ] `#Preview` que itera los seis temas

### Fase 5 — Captura · 4-5 días
- [ ] Entrada, preview del parseo, confirmar
- [ ] Edición inline antes de guardar
- [ ] **Guardar nunca se bloquea** — lo ambiguo entra con `needsReview`
- [ ] Onboarding para Apple Intelligence no disponible

**Cierre:** abrir → escribir → confirmar. Tres pasos, ni uno más.

### Fase 6 — Dashboard · 4-5 días
- [ ] Lista agrupada por día, con ingresos y gastos
- [ ] Total del mes, desglose por categoría (Swift Charts)
- [ ] Navegación entre meses
- [ ] Bandeja de `needsReview`

### Fase 7 — Presupuestos · 2-3 días
- [ ] CRUD mensual por categoría, con avance
- [ ] Presentación como dato, sin tono de regaño

### Fase 7.5 — Tarjetas y proyección · 8-11 días ← el diferenciador real
- [ ] CRUD de tarjetas con corte y fecha límite
- [ ] Deuda por tarjeta: saldo actual y saldo al corte, separados
- [ ] Al registrar con tarjeta, mostrar a qué corte cae y cuándo se paga
- [ ] Proyección de quincena: ingresos − compromisos con fecha = disponible
- [ ] Cuentas por cobrar en sección aparte, **nunca sumadas al disponible**
- [ ] App Intent "Agregar transacción" + guía de configuración de Shortcuts
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
- [ ] Crear lista, generar `CKShare`, invitar por share sheet
- [ ] Aceptar invitación, incluyendo con la app cerrada
- [ ] Registrar gasto con pagador y regla de división
- [ ] Vista de saldos: quién debe a quién, **con tendencia** además del número
- [ ] Registrar liquidación, con método de pago
- [ ] Recordatorio suave al cruzar umbral de monto o antigüedad (configurable)
- [ ] Permisos: participantes corrigen lo propio, no lo ajeno
- [ ] Prueba real en dos devices físicos con cuentas distintas

### Fase 9 — Consultas en lenguaje natural · 3-4 días
- [ ] Tools deterministas: `totalPorCategoria`, `comparaMeses`, `mayoresGastos`,
      `saldoDeLista`, `disponibleProyectado`, `deudaPorTarjeta`
- [ ] Sesión con tool calling
- [ ] **El modelo no calcula, solo narra.** Nunca le pases el historial crudo.
- [ ] Preguntas sugeridas para el estado vacío

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
| 7 — Presupuestos | 2-3 |
| 7.5 — Tarjetas y proyección | 8-11 |
| 7.8 — Tickets | 3-4 |
| 8 — Compartir | 6-8 |
| 9 — Consultas | 3-4 |
| 10 — Monetización | 2 |
| 11 — Lanzamiento | 4-5 |
| **Total** | **~53-71 días enfocados** |

En calendario real con otras cosas encima: **5 a 7 meses**.

Costo fijo: cuenta de desarrollador, $99 USD al año. Sin costos de servidor.

# Arquitectura

## Principio

El dominio no sabe nada del mundo exterior. Todo lo que toca un framework de Apple
—persistencia, modelo de lenguaje, compras, UI— vive detrás de un protocolo
definido en `LanaCore`.

Esto no es ceremonia. Tiene tres consecuencias concretas:

1. Puedes probar la lógica sin simulador ni Apple Intelligence.
2. Puedes cambiar SwiftData por otra cosa sin tocar features.
3. Las previews de SwiftUI corren con implementaciones falsas, instantáneas.

## Grafo de dependencias

```
                    ┌──────────┐
                    │   App    │
                    └────┬─────┘
                         │ conoce a todos, los ensambla
     ┌───────────┬───────┼────────┬─────────────┐
     ▼           ▼       ▼        ▼             ▼
 ┌────────┐ ┌────────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐
 │ Entry  │ │Dashboard│ │  Budgets  │ │  Cards   │ │LanaDesign│
 │Feature │ │ Feature │ │  Feature  │ │ Shared   │ │          │
 │        │ │         │ │           │ │ Insights │ │          │
 │        │ │         │ │           │ │ Settings │ │          │
 └───┬────┘ └───┬────┘ └─────┬──────┘ └────┬─────┘ └────┬─────┘
     └──────────┴────────────┴─────────────┘            │
                         │                              │
                         ▼                              │
                   ┌───────────┐ ◄──────────────────────┘
                   │ LanaCore  │
                   └─────▲─────┘
                         │ implementan sus protocolos
     ┌───────────────────┼──────────────────┐
     ▼                   ▼                  ▼
┌──────────┐    ┌────────────────┐   ┌──────────────┐
│LanaParsing│   │LanaPersistence │   │LanaPurchases │
└──────────┘    └────────────────┘   └──────────────┘
```

**Reglas:**
- `LanaCore` importa únicamente `Foundation`.
- Las implementaciones (`Parsing`, `Persistence`, `Purchases`) importan `LanaCore`
  y su framework de Apple. Nada más.
- Las features importan `LanaCore` y `LanaDesign`. **Nunca** una implementación
  concreta, y **nunca** otra feature.
- Solo `App` conoce las implementaciones concretas, y solo para inyectarlas.

Si te descubres queriendo romper una de estas, casi siempre significa que algo
que pusiste en una feature pertenece a `LanaCore`.

## Persistencia: Core Data, no SwiftData

`LanaPersistence` usa Core Data con `NSPersistentCloudKitContainer` porque
SwiftData no soporta CloudKit sharing y los gastos compartidos son parte de v1.0
(ADR-0004). Core Data no sale de ese paquete: el resto del sistema solo ve
`ExpenseStore`.

Los gastos personales viven en la zona privada. Cada lista compartida tiene su
propia zona de registro — los registros de la zona por defecto no se pueden
compartir, y eso no se retrofitea.

## Los ledgers

El núcleo del dominio es `Ledger`: pliega una secuencia de eventos inmutables y
produce saldos (ADR-0005). Es puro, no tiene dependencias, y es la parte del
sistema con más tests. Si algo va a estar bien probado en este repo, es esto.

Hay **dos ledgers independientes** y no se mezclan:

- **Deuda con tarjetas** — contra bancos. Tiene ciclos de corte, así que expone
  saldo actual y saldo al corte por separado.
- **Deuda con personas** — contra participantes de listas compartidas. No tiene
  fecha de vencimiento (ADR-0008).

Un mismo gasto compartido pagado con tarjeta alimenta los dos. Sumarlos daría un
número sin significado.

## Projection

`Projection` responde "¿cuánto me sobra?" a partir de ingresos esperados y
compromisos con fecha. Vive en `LanaCore`, es pura, y su regla central está en
ADR-0008: solo entra lo que tiene fecha. Las cuentas por cobrar se exponen aparte,
nunca dentro del disponible.

## Los protocolos que importan

```swift
public protocol ExpenseParsing: Sendable {
    func parse(_ text: String) async throws -> [ParseResult]
}

public protocol InsightQuerying: Sendable {
    func answer(_ question: String, tools: [LedgerTool]) async throws -> String
}

public protocol ExpenseStore: Sendable {
    func save(_ expense: Expense) async throws
    func expenses(in range: DateInterval) async throws -> [Expense]
    func delete(id: Expense.ID) async throws
}

public protocol PurchaseGating: Sendable {
    var isUnlocked: Bool { get async }
    func purchase() async throws
    func restore() async throws
}
```

Cada uno tiene dos implementaciones: la real y una de prueba. La de prueba vive
en el mismo paquete, marcada para uso en tests y previews.

## Composición

`App/AppDependencies.swift` es el único lugar donde se decide qué implementación
se usa. Se inyecta por el environment de SwiftUI.

```swift
@Observable
final class AppDependencies {
    let parser: any ExpenseParsing
    let store: any ExpenseStore
    let purchases: any PurchaseGating

    static func live() -> AppDependencies { /* implementaciones reales */ }
    static func preview() -> AppDependencies { /* implementaciones falsas */ }
}
```

## Estructura interna de una feature

```
EntryFeature/
├── Sources/
│   ├── EntryView.swift          # SwiftUI, sin lógica
│   ├── EntryModel.swift         # @Observable, toda la lógica y el estado
│   └── Components/              # subvistas privadas de esta feature
└── Tests/
    └── EntryModelTests.swift    # se prueba el modelo, no la vista
```

Las vistas no hacen `async` ni deciden nada. Llaman al modelo y lo renderizan.
Eso es lo que hace que las features sean testeables sin XCUITest.

## Concurrencia

Swift 6 con strict concurrency activado desde el día 1. Los modelos de dominio
son `Sendable` por ser structs de valores. Los modelos de vista van en `@MainActor`.
El parseo y la persistencia corren fuera del main actor.

Activarlo después duele mucho más que arrancar con él.

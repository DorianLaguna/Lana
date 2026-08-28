import Foundation

/// Dónde se guardan y leen las listas de gastos compartidos (Fase 8). `save`
/// es upsert directo — una `SharedList` es dato de referencia editable, no
/// un evento (mismo criterio que `Card`, ADR-0014). Los gastos y
/// liquidaciones de la lista sí son eventos: `recordSettlement` inserta un
/// `SettlementRecorded`, y los gastos compartidos se guardan por el mismo
/// `ExpenseStore.save(_:)` que cualquier otro gasto — `Expense` ya carga
/// `sharedListID`/`payer`/`split` desde antes de este bloque, así que no
/// hace falta un segundo camino de escritura para eso.
public protocol SharedListStore: Sendable { // swiftlint:disable:this protocol_naming_convention
    func save(_ list: SharedList) async throws
    func lists() async throws -> [SharedList]
    func delete(id: SharedListID) async throws
    func recordSettlement(_ settlement: SettlementRecorded) async throws
    /// El log completo, sin filtrar por lista — `PersonLedger` necesita
    /// eventos fuera de un rango visible para resolver correcciones/
    /// anulaciones (mismo criterio que `CardPaymentStore.events()`).
    func events() async throws -> [ExpenseEvent]
}

/// Implementación en memoria para tests y `#Preview`.
public actor InMemorySharedListStore: SharedListStore {
    private var listsByID: [SharedListID: SharedList]
    private var storedEvents: [ExpenseEvent]

    public init(seed: [SharedList] = [], events: [ExpenseEvent] = []) {
        listsByID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
        storedEvents = events
    }

    public func save(_ list: SharedList) async throws {
        listsByID[list.id] = list
    }

    public func lists() async throws -> [SharedList] {
        listsByID.values.sorted { $0.name < $1.name }
    }

    public func delete(id: SharedListID) async throws {
        listsByID.removeValue(forKey: id)
    }

    public func recordSettlement(_ settlement: SettlementRecorded) async throws {
        storedEvents.append(.settlementRecorded(settlement))
    }

    public func events() async throws -> [ExpenseEvent] {
        storedEvents
    }

    /// Para que los tests puedan sembrar gastos compartidos igual que lo
    /// haría `ExpenseStore.save(_:)` en producción, sin duplicar ese store.
    public func seedEvent(_ event: ExpenseEvent) async {
        storedEvents.append(event)
    }
}

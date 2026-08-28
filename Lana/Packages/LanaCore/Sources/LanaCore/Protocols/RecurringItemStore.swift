import Foundation

/// Cómo se guardan y leen ingresos/gastos recurrentes. Igual que
/// `CardStore` — `RecurringItem` es dato de referencia editable, no un
/// evento (ADR-0014, mismo razonamiento).
///
/// Nombre fijado por el mismo patrón que `ExpenseStore` — "Store" es la
/// excepción explícita a la regla -ing/-able de Docs/CONVENTIONS.md para
/// protocolos de persistencia.
public protocol RecurringItemStore: Sendable { // swiftlint:disable:this protocol_naming_convention
    func save(_ item: RecurringItem) async throws
    func items() async throws -> [RecurringItem]
    func delete(id: RecurringItemID) async throws
}

/// Implementación en memoria para tests y `#Preview`.
public actor InMemoryRecurringItemStore: RecurringItemStore {
    private var storage: [RecurringItemID: RecurringItem]

    public init(seed: [RecurringItem] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func save(_ item: RecurringItem) async throws {
        storage[item.id] = item
    }

    public func items() async throws -> [RecurringItem] {
        storage.values.sorted { $0.dayOfMonth < $1.dayOfMonth }
    }

    public func delete(id: RecurringItemID) async throws {
        storage.removeValue(forKey: id)
    }
}

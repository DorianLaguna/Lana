import Foundation

/// Cómo se guardan y leen transacciones. La implementación real
/// (`LanaPersistence`, Fase 2) traduce esto a eventos append-only por
/// dentro — el resto del sistema solo conoce este protocolo.
///
/// Nombre fijado por Docs/ARCHITECTURE.md — "Store" es la excepción explícita
/// a la regla -ing/-able de Docs/CONVENTIONS.md para protocolos de persistencia.
public protocol ExpenseStore: Sendable { // swiftlint:disable:this protocol_naming_convention
    func save(_ expense: Expense) async throws
    func expenses(in range: DateInterval) async throws -> [Expense]
    func delete(id: Expense.ID) async throws
}

/// Implementación en memoria para tests y `#Preview`.
public actor InMemoryExpenseStore: ExpenseStore {
    private var storage: [Expense.ID: Expense]

    public init(seed: [Expense] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func save(_ expense: Expense) async throws {
        storage[expense.id] = expense
    }

    public func expenses(in range: DateInterval) async throws -> [Expense] {
        storage.values
            .filter { range.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    public func delete(id: Expense.ID) async throws {
        storage.removeValue(forKey: id)
    }
}

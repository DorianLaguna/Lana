import Foundation

/// Cómo se guardan y leen tarjetas. A diferencia de `ExpenseStore`, esto no
/// es un log de eventos — `Card` es dato de referencia editable, como
/// `SharedList` (ADR-0014). El saldo de una tarjeta nunca vive aquí: se
/// deriva de los gastos con `paymentMethod` apuntando a su `CardID`.
///
/// Nombre fijado por el mismo patrón que `ExpenseStore` — "Store" es la
/// excepción explícita a la regla -ing/-able de Docs/CONVENTIONS.md para
/// protocolos de persistencia.
public protocol CardStore: Sendable { // swiftlint:disable:this protocol_naming_convention
    func save(_ card: Card) async throws
    func cards() async throws -> [Card]
    func delete(id: CardID) async throws
}

/// Implementación en memoria para tests y `#Preview`.
public actor InMemoryCardStore: CardStore {
    private var storage: [CardID: Card]

    public init(seed: [Card] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func save(_ card: Card) async throws {
        storage[card.id] = card
    }

    public func cards() async throws -> [Card] {
        storage.values.sorted { $0.alias < $1.alias }
    }

    public func delete(id: CardID) async throws {
        storage.removeValue(forKey: id)
    }
}

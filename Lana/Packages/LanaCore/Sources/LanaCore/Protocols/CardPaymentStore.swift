import Foundation

/// Registrar un pago a tarjeta y leer el log crudo de eventos que
/// `CardLedger` necesita para calcular deuda neta de pagos
/// (`outstandingStatementBalance`). Separado de `ExpenseStore` a propósito:
/// un pago a tarjeta no es un gasto (Docs/CLAUDE.md), y `CardLedger` opera
/// sobre `[ExpenseEvent]` crudos, no sobre el `[Expense]` ya plegado que
/// expone `ExpenseStore.expenses(in:)` — ese ya perdió la información de
/// correcciones/anulaciones fuera de rango que `CardLedger` sí necesita
/// para resolver bien.
///
/// Nombre fijado por el mismo patrón que `ExpenseStore`/`CardStore` —
/// "Store" es la excepción explícita a la regla -ing/-able de
/// Docs/CONVENTIONS.md para protocolos de persistencia.
public protocol CardPaymentStore: Sendable { // swiftlint:disable:this protocol_naming_convention
    func recordPayment(_ payment: CardPaymentRecorded) async throws
    /// El log completo, sin filtrar por rango — ver el doc comment del
    /// protocolo para el porqué.
    func events() async throws -> [ExpenseEvent]
}

/// Implementación en memoria para tests y `#Preview`.
public actor InMemoryCardPaymentStore: CardPaymentStore {
    private var storage: [ExpenseEvent]

    public init(seed: [ExpenseEvent] = []) {
        storage = seed
    }

    public func recordPayment(_ payment: CardPaymentRecorded) async throws {
        storage.append(.cardPaymentRecorded(payment))
    }

    public func events() async throws -> [ExpenseEvent] {
        storage
    }
}

import Foundation

/// Cuánto se gastó en una categoría, para un desglose (dashboard mensual o
/// detalle de una tarjeta). Vive en `LanaCore` porque más de una feature lo
/// necesita con la misma forma, y las features no pueden importarse entre
/// sí (Docs/ARCHITECTURE.md).
public struct CategoryTotal: Identifiable, Sendable {
    public var id: String {
        category
    }

    public let category: String
    public let amount: Decimal
    public let currency: Currency

    public init(category: String, amount: Decimal, currency: Currency) {
        self.category = category
        self.amount = amount
        self.currency = currency
    }
}

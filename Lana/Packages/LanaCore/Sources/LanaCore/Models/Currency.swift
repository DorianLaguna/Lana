import Foundation

/// Un código de moneda ISO 4217 (`MXN`, `USD`, ...).
public struct Currency: Sendable, Hashable, Codable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }
}

public extension Currency {
    /// Peso mexicano.
    static let mxn = Currency(rawValue: "MXN")
    /// Dólar estadounidense.
    static let usd = Currency(rawValue: "USD")
}

/// Tasa de conversión entre dos monedas en una fecha específica. Se guarda
/// junto al evento que la usó y nunca se recalcula — el monto original, la
/// moneda original y la tasa del día viajan juntos (Docs/CONVENTIONS.md →
/// Multi-moneda).
public struct ExchangeRate: Sendable, Hashable, Codable {
    public let from: Currency
    public let to: Currency
    public let rate: Decimal
    public let date: Date

    public init(from: Currency, to: Currency, rate: Decimal, date: Date) {
        self.from = from
        self.to = to
        self.rate = rate
        self.date = date
    }

    /// Convierte `amount` (en la moneda `from`) a la moneda `to`. Es una
    /// operación de presentación, no de guardado — nunca se usa para
    /// sobrescribir el monto original de un evento.
    public func converted(_ amount: Money) throws -> Money {
        guard amount.currency == from else {
            throw MoneyError.currencyMismatch(amount.currency, from)
        }
        return Money(amount: amount.amount * rate, currency: to)
    }
}

import Foundation

/// Un monto de dinero. Nunca `Double` ni `Float` — `Decimal` es exacto para
/// aritmética financiera (Docs/CONVENTIONS.md → Dinero).
///
/// Trampa real de Swift: un literal fraccionario como `0.1` asignado a un
/// `Decimal` pasa primero por `Double` (`Decimal(1234.56)` puede dar
/// `1234.5599999999997952`). Para un monto exacto que no venga de una suma o
/// resta ya hecha en `Decimal`, constrúyelo con `Decimal(string: "1234.56")!`,
/// nunca con el literal `1234.56` directo.
public struct Money: Sendable, Hashable, Codable {
    public let amount: Decimal
    public let currency: Currency

    public init(amount: Decimal, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    public static func zero(_ currency: Currency) -> Money {
        Money(amount: 0, currency: currency)
    }
}

/// Sumar o comparar `Money` de monedas distintas es un error — nunca una
/// conversión silenciosa (Docs/CONVENTIONS.md → Dinero).
public enum MoneyError: LocalizedError, Sendable {
    case currencyMismatch(Currency, Currency)

    public var errorDescription: String? {
        switch self {
        case let .currencyMismatch(first, second):
            "No se puede combinar \(first.rawValue) con \(second.rawValue) sin una conversión explícita."
        }
    }
}

public extension Money {
    /// Suma dos montos. Truena si son de monedas distintas.
    static func + (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(lhs.currency, rhs.currency)
        }
        return Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)
    }

    /// Resta dos montos. Truena si son de monedas distintas.
    static func - (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(lhs.currency, rhs.currency)
        }
        return Money(amount: lhs.amount - rhs.amount, currency: lhs.currency)
    }

    /// Invierte el signo de un monto, misma moneda.
    static prefix func - (value: Money) -> Money {
        Money(amount: -value.amount, currency: value.currency)
    }

    /// Escala un monto por un factor sin moneda (p. ej. un porcentaje).
    static func * (lhs: Money, rhs: Decimal) -> Money {
        Money(amount: lhs.amount * rhs, currency: lhs.currency)
    }
}

extension Money: Comparable {
    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(
            lhs.currency == rhs.currency,
            "Comparar montos de monedas distintas no tiene sentido sin conversión explícita.")
        return lhs.amount < rhs.amount
    }
}

public extension Money {
    /// Un monto escrito (`$1,234.00`). Vive en `LanaCore` porque más de una
    /// feature lo necesita (Dashboard, Tarjetas) y las features no pueden
    /// importarse entre sí (Docs/ARCHITECTURE.md).
    ///
    /// Con **locale fijo**, igual que las fechas (ADR-0047). Sin él seguía al
    /// dispositivo: con región distinta de México, los mismos pesos salían
    /// "MX$1,234.50", y en Alemania "1.234,50 MX$". La moneda ya la dice
    /// `currency`; el formato no tiene por qué cambiar según dónde esté el
    /// teléfono.
    func formatted() -> String {
        amount.formatted(.currency(code: currency.rawValue).locale(LanaDateFormat.locale))
    }
}

extension Decimal {
    /// Redondea a `scale` decimales con el modo dado. Se usa para repartir
    /// montos entre participantes sin perder centavos (`SplitRule`).
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}

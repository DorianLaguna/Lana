import Foundation

/// Un compromiso de dinero con fecha cierta — un cargo o ingreso que se sabe
/// cuándo va a pasar (el pago de una tarjeta que vence el 24, la renta el 1).
/// Las cuentas por cobrar sin fecha (saldos de `PersonLedger`) nunca entran
/// aquí — por construcción, no hay forma de pasarlas (ADR-0008).
public struct Commitment: Sendable, Hashable {
    public let concept: String
    /// Negativo = salida de dinero; positivo = entrada.
    public let amount: Money
    public let date: Date

    public init(concept: String, amount: Money, date: Date) {
        self.concept = concept
        self.amount = amount
        self.date = date
    }
}

public enum ProjectionError: LocalizedError, Sendable {
    case mixedCurrencies(Currency, Currency)

    public var errorDescription: String? {
        switch self {
        case let .mixedCurrencies(first, second):
            "No se puede proyectar mezclando \(first.rawValue) y \(second.rawValue) sin conversión explícita."
        }
    }
}

/// Disponible proyectado: dinero real más los compromisos con fecha hasta
/// `date`. Las cuentas por cobrar nunca entran — solo lo que tiene fecha
/// (ADR-0008). El disponible siempre es conservador, nunca promete dinero
/// que no ha llegado.
public enum Projection {
    /// El disponible: `currentBalance` más los `commitments` con fecha hasta
    /// e incluyendo `date`. Truena si algún compromiso está en otra moneda.
    public static func available(currentBalance: Money, commitments: [Commitment], through date: Date) throws -> Money {
        var total = currentBalance
        for commitment in commitments where commitment.date <= date {
            guard commitment.amount.currency == currentBalance.currency else {
                throw ProjectionError.mixedCurrencies(currentBalance.currency, commitment.amount.currency)
            }
            total = try total + commitment.amount
        }
        return total
    }
}

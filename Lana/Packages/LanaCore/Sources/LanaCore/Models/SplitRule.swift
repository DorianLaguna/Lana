import Foundation

/// Cómo se divide un gasto compartido entre los participantes de una lista.
/// El caso `proportional` congela las participaciones concretas en el
/// evento — nunca una referencia a los ingresos vigentes de la lista
/// (ADR-0007): cambiar la proporción aplica hacia adelante, el historial no
/// se recalcula.
public enum SplitRule: Sendable, Hashable, Codable {
    case equally(among: [ParticipantID])
    case payerOnly
    case proportional(shares: [ParticipantID: Decimal])
    case percentage(shares: [ParticipantID: Decimal])
    case exactAmounts(amounts: [ParticipantID: Decimal])
}

public enum SplitRuleError: LocalizedError, Sendable {
    case emptyParticipants
    case sharesDontSumToOne(sum: Decimal)
    case percentagesDontSumTo100(sum: Decimal)
    case amountsDontMatchTotal(sum: Decimal, total: Decimal)

    public var errorDescription: String? {
        switch self {
        case .emptyParticipants:
            "Un split necesita al menos un participante."
        case let .sharesDontSumToOne(sum):
            "Las participaciones proporcionales suman \(sum), no 1."
        case let .percentagesDontSumTo100(sum):
            "Los porcentajes suman \(sum), no 100."
        case let .amountsDontMatchTotal(sum, total):
            "Los montos exactos suman \(sum), pero el total es \(total)."
        }
    }
}

extension SplitRule {
    /// Cuánto le corresponde a cada participante del monto `total`. La suma
    /// de las partes siempre es exactamente `total` — el residuo del
    /// redondeo, si lo hay, se ajusta de forma determinista en el
    /// participante que ordena último por `ParticipantID`.
    public func portions(of total: Money) throws -> [ParticipantID: Money] {
        switch self {
        case .payerOnly:
            return [:]
        case let .equally(among):
            guard !among.isEmpty else { throw SplitRuleError.emptyParticipants }
            let fraction = Decimal(1) / Decimal(among.count)
            let shares = Dictionary(uniqueKeysWithValues: among.map { ($0, fraction) })
            return try Self.distribute(total: total, fractionalShares: shares, expectedSum: nil)
        case let .proportional(shares):
            let sum = shares.values.reduce(Decimal(0), +)
            guard sum == 1 else { throw SplitRuleError.sharesDontSumToOne(sum: sum) }
            return try Self.distribute(total: total, fractionalShares: shares, expectedSum: 1)
        case let .percentage(shares):
            let sum = shares.values.reduce(Decimal(0), +)
            guard sum == 100 else { throw SplitRuleError.percentagesDontSumTo100(sum: sum) }
            let fractionalShares = shares.mapValues { $0 / 100 }
            return try Self.distribute(total: total, fractionalShares: fractionalShares, expectedSum: nil)
        case let .exactAmounts(amounts):
            let sum = amounts.values.reduce(Decimal(0), +)
            guard sum == total.amount else {
                throw SplitRuleError.amountsDontMatchTotal(sum: sum, total: total.amount)
            }
            return amounts.mapValues { Money(amount: $0, currency: total.currency) }
        }
    }

    private static func distribute(
        total: Money,
        fractionalShares: [ParticipantID: Decimal],
        expectedSum: Decimal?) throws -> [ParticipantID: Money] {
        guard !fractionalShares.isEmpty else { throw SplitRuleError.emptyParticipants }
        if let expectedSum {
            let sum = fractionalShares.values.reduce(Decimal(0), +)
            guard sum == expectedSum else { throw SplitRuleError.sharesDontSumToOne(sum: sum) }
        }

        let ordered = fractionalShares.keys.sorted()
        var portions: [ParticipantID: Money] = [:]
        var distributed = Decimal(0)
        for participant in ordered.dropLast() {
            let fraction = fractionalShares[participant] ?? 0
            let amount = (total.amount * fraction).rounded(scale: 2, mode: .down)
            portions[participant] = Money(amount: amount, currency: total.currency)
            distributed += amount
        }
        if let last = ordered.last {
            portions[last] = Money(amount: total.amount - distributed, currency: total.currency)
        }
        return portions
    }
}

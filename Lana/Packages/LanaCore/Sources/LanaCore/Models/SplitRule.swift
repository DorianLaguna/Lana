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
    /// de las partes siempre es exactamente `total`, y ninguna parte se aleja
    /// más de un centavo de la exacta (ver `distribute`).
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

    /// Reparte `total` en centavos según `fractionalShares`, por el método
    /// del mayor residuo: cada parte exacta se trunca a centavos y los
    /// centavos que sobran se dan, de uno en uno, a quienes más perdieron al
    /// truncar. Empates, al que ordena último por `ParticipantID`.
    ///
    /// Antes todo el residuo iba al último participante, y como 1/7 no cabe
    /// exacto en un `Decimal`, 350 entre 7 daba 49.99 a seis personas y 50.06
    /// a una.
    private static func distribute(
        total: Money,
        fractionalShares: [ParticipantID: Decimal],
        expectedSum: Decimal?) throws -> [ParticipantID: Money] {
        guard !fractionalShares.isEmpty else { throw SplitRuleError.emptyParticipants }
        if let expectedSum {
            let sum = fractionalShares.values.reduce(Decimal(0), +)
            guard sum == expectedSum else { throw SplitRuleError.sharesDontSumToOne(sum: sum) }
        }

        let cent = Decimal(string: "0.01") ?? 0
        var amounts: [ParticipantID: Decimal] = [:]
        var remainders: [(participant: ParticipantID, remainder: Decimal)] = []
        for participant in fractionalShares.keys.sorted() {
            // Seis decimales primero: una fracción periódica guardada en
            // `Decimal` deja 49.9999…, que truncado a centavos perdería uno.
            let exact = (total.amount * (fractionalShares[participant] ?? 0)).rounded(scale: 6, mode: .plain)
            let truncated = exact.rounded(scale: 2, mode: .down)
            amounts[participant] = truncated
            remainders.append((participant, exact - truncated))
        }

        let distributed = amounts.values.reduce(Decimal(0), +)
        let leftoverCents = NSDecimalNumber(decimal: ((total.amount - distributed) / cent).rounded(
            scale: 0,
            mode: .plain))
            .intValue
        if leftoverCents > 0 {
            let byRemainder = remainders.sorted {
                $0.remainder == $1.remainder ? $0.participant > $1.participant : $0.remainder > $1.remainder
            }
            for index in 0 ..< leftoverCents {
                amounts[byRemainder[index % byRemainder.count].participant, default: 0] += cent
            }
        } else if leftoverCents < 0 {
            let bySmallestRemainder = remainders.sorted {
                $0.remainder == $1.remainder ? $0.participant < $1.participant : $0.remainder < $1.remainder
            }
            for index in 0 ..< -leftoverCents {
                amounts[bySmallestRemainder[index % bySmallestRemainder.count].participant, default: 0] -= cent
            }
        }
        return amounts.mapValues { Money(amount: $0, currency: total.currency) }
    }
}

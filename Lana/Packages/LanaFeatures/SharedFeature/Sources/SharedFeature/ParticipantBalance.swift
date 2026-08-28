import Foundation
import LanaCore

/// El saldo de un participante en una lista, para mostrar — no vive en
/// `LanaCore` porque no es dominio, es la forma en que esta feature
/// presenta lo que `PersonLedger.netBalances` ya calculó.
public struct ParticipantBalance: Sendable, Identifiable {
    /// Hacia dónde se mueve el saldo — ADR-0008 pide priorizar la
    /// tendencia sobre el número puntual: un saldo que oscila alrededor de
    /// cero no requiere acción, uno que crece siempre hacia el mismo lado
    /// sí.
    public enum Trend: Sendable {
        case growing
        case shrinking
        case stable
    }

    public let participant: Participant
    /// Positivo: le deben. Negativo: debe.
    public let amount: Decimal
    public let currency: Currency
    public let trend: Trend

    public var id: ParticipantID {
        participant.id
    }

    public init(participant: Participant, amount: Decimal, currency: Currency, trend: Trend) {
        self.participant = participant
        self.amount = amount
        self.currency = currency
        self.trend = trend
    }
}

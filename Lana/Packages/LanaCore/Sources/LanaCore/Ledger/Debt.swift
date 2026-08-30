import Foundation

/// Una transferencia que salda (parte de) una deuda entre dos participantes,
/// producto de `PersonLedger.simplifiedDebts(in:currency:)`.
public struct Debt: Sendable, Hashable {
    public let from: ParticipantID
    public let to: ParticipantID
    public let amount: Money

    public init(from: ParticipantID, to: ParticipantID, amount: Money) {
        self.from = from
        self.to = to
        self.amount = amount
    }
}

/// Un gasto que contribuyó a la relación directa entre dos participantes
/// (`PersonLedger.contributions(between:and:in:)`) — el detalle de "por qué"
/// detrás de un `Debt`.
public struct DebtContribution: Sendable, Hashable, Identifiable {
    public let id: EventID
    public let date: Date
    public let concept: String
    /// El monto total del gasto, no la parte de nadie.
    public let amount: Money
    public let payer: ParticipantID
    /// Lo que le tocó a `from` en este gasto, según su `SplitRule`.
    public let fromShare: Money
    /// Lo que le tocó a `to` en este gasto.
    public let toShare: Money
    /// Positivo: este gasto aumenta lo que `from` le debe a `to` (pagó
    /// `to`). Negativo: lo reduce (pagó `from`).
    public let signedEffect: Decimal

    public init(
        id: EventID,
        date: Date,
        concept: String,
        amount: Money,
        payer: ParticipantID,
        fromShare: Money,
        toShare: Money,
        signedEffect: Decimal) {
        self.id = id
        self.date = date
        self.concept = concept
        self.amount = amount
        self.payer = payer
        self.fromShare = fromShare
        self.toShare = toShare
        self.signedEffect = signedEffect
    }
}

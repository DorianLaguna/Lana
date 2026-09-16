import Foundation

/// Una transferencia que salda (parte de) una deuda entre dos participantes,
/// producto de `PersonLedger.settlementPlan(in:currency:)`.
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

/// Un movimiento que movió el saldo de un participante en una lista
/// (`PersonLedger.balanceEntries(for:in:currency:)`): un gasto que pagó, uno
/// en que le tocó parte, o una liquidación.
public struct BalanceEntry: Sendable, Hashable, Identifiable {
    public let id: EventID
    public let date: Date
    public let concept: String
    /// El monto total del gasto o de la liquidación.
    public let amount: Money
    /// Quién pagó el gasto, o quién pagó la liquidación.
    public let payer: ParticipantID
    /// Lo que le tocó al participante en el gasto; cero en una liquidación.
    public let share: Money
    /// `true` si es una liquidación y no un gasto.
    public let isSettlement: Bool
    /// Cuánto movió su saldo. Positivo: le deben más (pagó por otros, o pagó
    /// una liquidación). Negativo: debe más.
    public let effect: Decimal

    public init(
        id: EventID,
        date: Date,
        concept: String,
        amount: Money,
        payer: ParticipantID,
        share: Money,
        isSettlement: Bool = false,
        effect: Decimal) {
        self.id = id
        self.date = date
        self.concept = concept
        self.amount = amount
        self.payer = payer
        self.share = share
        self.isSettlement = isSettlement
        self.effect = effect
    }
}

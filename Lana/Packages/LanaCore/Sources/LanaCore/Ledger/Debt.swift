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

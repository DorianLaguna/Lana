/// Cómo se pagó una transacción. Débito y crédito referencian una tarjeta
/// concreta — el débito no genera deuda (es dinero real saliendo), el
/// crédito sí (`CardLedger`).
public enum PaymentMethod: Sendable, Hashable, Codable {
    case cash
    case debit(cardID: CardID)
    case credit(cardID: CardID)
    case transfer
}

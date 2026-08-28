import Foundation

/// Vista de lectura de una transacción, para `ExpenseStore` y las features.
/// No es el evento persistido — `LanaPersistence` la reconstruye plegando
/// los eventos de `LanaCore` (ADR-0005). Guardar una corrección aquí emite
/// internamente un `ExpenseCorrected`, no sobrescribe nada.
public struct Expense: Sendable, Hashable, Identifiable, Codable {
    public enum Kind: Sendable, Hashable, Codable {
        case expense
        case income
    }

    public let id: ExpenseID
    public var kind: Kind
    public var amount: Money
    public var concept: String
    /// `nil` para ingresos — solo los gastos se categorizan (v1.0).
    public var category: String?
    /// Propiedad del usuario, resuelta por fuzzy match (ADR-0011). `nil` si
    /// no aplica o el modelo no propuso nada específico.
    public var subcategory: String?
    public var date: Date
    public var paymentMethod: PaymentMethod?
    public var needsReview: Bool
    public var sharedListID: SharedListID?
    public var payer: ParticipantID?
    public var split: SplitRule?

    public init(
        id: ExpenseID = ExpenseID(),
        kind: Kind,
        amount: Money,
        concept: String,
        category: String? = nil,
        subcategory: String? = nil,
        date: Date,
        paymentMethod: PaymentMethod? = nil,
        needsReview: Bool = false,
        sharedListID: SharedListID? = nil,
        payer: ParticipantID? = nil,
        split: SplitRule? = nil) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.concept = concept
        self.category = category
        self.subcategory = subcategory
        self.date = date
        self.paymentMethod = paymentMethod
        self.needsReview = needsReview
        self.sharedListID = sharedListID
        self.payer = payer
        self.split = split
    }
}

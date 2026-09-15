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
    /// En qué se fue, o de dónde vino. Un gasto usa las once de
    /// `SuggestedCategory`; un ingreso, las ocho de `IncomeCategory`
    /// (ADR-0040) — son catálogos distintos y nunca se mezclan.
    ///
    /// `nil` mientras nadie la haya puesto: el parser no clasifica ingresos,
    /// así que uno capturado por voz llega sin categoría hasta que se edite.
    public var category: String?
    /// Propiedad del usuario, resuelta por fuzzy match (ADR-0011). `nil` si
    /// no aplica o el modelo no propuso nada específico. Aplica igual a
    /// gastos e ingresos.
    public var subcategory: String?
    public var date: Date
    public var paymentMethod: PaymentMethod?
    public var needsReview: Bool
    public var sharedListID: SharedListID?
    public var payer: ParticipantID?
    public var split: SplitRule?
    /// El recurrente del que salió este movimiento, o `nil` si se capturó a
    /// mano. Es lo que dice que un recurrente ya se registró en el mes
    /// (`RecurringItem.registration(in:forMonthOf:calendar:)`, ADR-0042): al
    /// borrar el movimiento, el recurrente vuelve a quedar pendiente solo.
    public var recurringItemID: RecurringItemID?

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
        split: SplitRule? = nil,
        recurringItemID: RecurringItemID? = nil) {
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
        self.recurringItemID = recurringItemID
    }
}

import Foundation

/// Un ingreso o gasto que se repite cada mes — sueldo, renta,
/// suscripciones. Es una plantilla, no un hecho financiero: registrar la
/// ocurrencia de este mes crea un `Expense`/ingreso normal
/// (`RecurringItemsModel.register(_:)` en `DashboardFeature`), a un toque
/// del usuario — nunca se postea solo. Un `RecurringItem` en silencio que
/// nadie confirmó ese momento no es distinto de capturar sin revisar, y
/// `CLAUDE.md` es explícito en que lo automático siempre entra
/// `needsReview`; más simple todavía es que aquí nunca sea automático.
public struct RecurringItem: Sendable, Hashable, Identifiable, Codable {
    public let id: RecurringItemID
    public var name: String
    public var amount: Money
    public var kind: Expense.Kind
    /// `nil` para ingresos — igual que `Expense.category` (solo los gastos
    /// se categorizan, v1.0).
    public var category: String?
    /// `nil` para ingresos, igual que `category` — mismo campo que
    /// `Expense.subcategory`, para que un recurrente registrado no pierda
    /// esa granularidad frente a un gasto capturado a mano.
    public var subcategory: String?
    /// El día del mes en que normalmente cae, solo como referencia visual
    /// — no dispara nada por sí mismo.
    public var dayOfMonth: Int
    /// Con qué se paga, igual que `Expense.paymentMethod` — `nil` para
    /// ingresos, igual que `category` (Docs/CLAUDE.md → un ingreso no se
    /// categoriza; tampoco tiene "con qué se pagó").
    public var paymentMethod: PaymentMethod?
    /// El primer día del mes en que ya se registró una ocurrencia — evita
    /// que `RecurringItemsModel.registerDueItems()` postee dos veces el
    /// mismo mes. `nil` si nunca se ha registrado. No bloquea el registro
    /// manual explícito, que puede repetirse a propósito.
    public var lastRegisteredMonth: Date?

    public init(
        id: RecurringItemID = RecurringItemID(),
        name: String,
        amount: Money,
        kind: Expense.Kind,
        category: String? = nil,
        subcategory: String? = nil,
        dayOfMonth: Int,
        paymentMethod: PaymentMethod? = nil,
        lastRegisteredMonth: Date? = nil) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw RecurringItemError.emptyName
        }
        guard (1 ... 31).contains(dayOfMonth) else {
            throw RecurringItemError.invalidDayOfMonth(dayOfMonth)
        }
        self.id = id
        self.name = trimmedName
        self.amount = amount
        self.kind = kind
        self.category = kind == .income ? nil : category
        self.subcategory = kind == .income ? nil : subcategory
        self.dayOfMonth = dayOfMonth
        self.paymentMethod = kind == .income ? nil : paymentMethod
        self.lastRegisteredMonth = lastRegisteredMonth
    }
}

public enum RecurringItemError: LocalizedError, Sendable {
    case emptyName
    case invalidDayOfMonth(Int)

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            "Ponle un nombre."
        case let .invalidDayOfMonth(day):
            "\(day) no es un día del mes válido (1-31)."
        }
    }
}

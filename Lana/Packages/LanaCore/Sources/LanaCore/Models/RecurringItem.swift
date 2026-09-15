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
    /// La categoría de la plantilla: `SuggestedCategory` si es gasto,
    /// `IncomeCategory` si es ingreso (ADR-0040). Un sueldo recurrente puede
    /// decir que es sueldo, y así lo hereda cada ocurrencia que se registre.
    public var category: String?
    /// La subcategoría abierta — mismo campo que `Expense.subcategory`, para
    /// que un recurrente registrado no pierda esa granularidad frente a algo
    /// capturado a mano.
    public var subcategory: String?
    /// El día del mes en que normalmente cae, solo como referencia visual
    /// — no dispara nada por sí mismo.
    public var dayOfMonth: Int
    /// Con qué se paga, igual que `Expense.paymentMethod` — `nil` para
    /// ingresos, igual que `category` (Docs/CLAUDE.md → un ingreso no se
    /// categoriza; tampoco tiene "con qué se pagó").
    public var paymentMethod: PaymentMethod?
    /// **Dato heredado; Lana ya no lo escribe (ADR-0042).** Antes de que cada
    /// movimiento guardara de qué recurrente salió, esta marca era la única
    /// forma de saber que ya se registró en el mes, y por eso borrar el
    /// movimiento no reabría el recurrente. Se sigue leyendo solo para no
    /// volver a pedir ni contar dos veces lo que se registró así.
    public var lastRegisteredMonth: Date?
    /// El primer día del mes en que ya corrió el registro automático de este
    /// recurrente (`RecurringItemsModel.registerDueItems()`). Es lo que evita
    /// que un movimiento borrado a propósito vuelva a aparecer solo: lo
    /// automático pasa una vez por mes, y después registrar otra vez es
    /// decisión del usuario (ADR-0042).
    public var lastAutoRegisteredMonth: Date?

    public init(
        id: RecurringItemID = RecurringItemID(),
        name: String,
        amount: Money,
        kind: Expense.Kind,
        category: String? = nil,
        subcategory: String? = nil,
        dayOfMonth: Int,
        paymentMethod: PaymentMethod? = nil,
        lastRegisteredMonth: Date? = nil,
        lastAutoRegisteredMonth: Date? = nil) throws {
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
        self.category = category
        self.subcategory = subcategory
        self.dayOfMonth = dayOfMonth
        // El método de pago sí sigue siendo solo de gastos: un ingreso no se
        // "paga" con nada (Docs/CLAUDE.md).
        self.paymentMethod = kind == .income ? nil : paymentMethod
        self.lastRegisteredMonth = lastRegisteredMonth
        self.lastAutoRegisteredMonth = lastAutoRegisteredMonth
    }
}

public extension RecurringItem {
    /// Cómo se sabe que un recurrente ya se registró en un mes.
    enum Registration: Sendable, Hashable {
        /// Hay un movimiento vigente que salió de este recurrente. Borrarlo
        /// deja el recurrente pendiente otra vez.
        case linked(Expense)
        /// Se registró antes de que los movimientos guardaran de qué
        /// recurrente salieron (`lastRegisteredMonth`): se sabe que sí, no cuándo.
        case legacy
    }

    /// La ocurrencia en el mes de `date`, con el día recortado al último del
    /// mes — un recurrente del 31 cae el 30 en septiembre.
    func occurrence(inMonthOf date: Date, calendar: Calendar = .current) -> Date? {
        PayPeriod.occurrence(of: dayOfMonth, inMonthOf: date, calendar: calendar)
    }

    /// `true` si la ocurrencia del mes de `date` ya llegó; el mismo día cuenta.
    func isDue(asOf date: Date, calendar: Calendar = .current) -> Bool {
        guard let occurrence = occurrence(inMonthOf: date, calendar: calendar) else { return false }
        return calendar.startOfDay(for: date) >= occurrence
    }

    /// Si este recurrente ya se registró en el mes de `date`, y cómo. `nil`
    /// si sigue pendiente.
    ///
    /// Se deriva de los movimientos vigentes, no de una marca guardada
    /// (ADR-0042), con el mismo principio que los saldos (ADR-0005): borrar
    /// el movimiento emite una anulación, deja de aparecer en `expenses`, y
    /// el recurrente vuelve a quedar pendiente sin que nadie lo desmarque.
    /// `expenses` tiene que cubrir el mes completo de `date`.
    func registration(
        in expenses: [Expense],
        forMonthOf date: Date,
        calendar: Calendar = .current) -> Registration? {
        let linked = expenses
            .filter { $0.recurringItemID == id && calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            .min { $0.date < $1.date }
        if let linked {
            return .linked(linked)
        }
        if let lastRegisteredMonth, calendar.isDate(lastRegisteredMonth, equalTo: date, toGranularity: .month) {
            return .legacy
        }
        return nil
    }

    /// `true` si el registro automático ya corrió en el mes de `date`.
    func hasAutoRegistered(inMonthOf date: Date, calendar: Calendar = .current) -> Bool {
        guard let lastAutoRegisteredMonth else { return false }
        return calendar.isDate(lastAutoRegisteredMonth, equalTo: date, toGranularity: .month)
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

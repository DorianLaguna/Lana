import Foundation
import LanaCore

/// El resultado del parseo, editable en pantalla antes de guardar. Existe
/// para que el usuario corrija cualquier campo sin que eso bloquee guardar
/// — lo ambiguo entra con `needsReview`, nunca impide confirmar
/// (Docs/PLAN.md → Fase 5).
public struct DraftTransaction: Equatable, Sendable, Identifiable {
    public let id: ExpenseID
    public var kind: Expense.Kind
    public var amount: Decimal
    public var currency: Currency
    public var concept: String
    public var category: String
    /// La categoría que propuso el parser, antes de cualquier edición del
    /// usuario. Compararla contra `category` al confirmar es cómo se
    /// detecta una corrección para alimentar el vocabulario (ADR-0012).
    public let originalCategory: String
    public var subcategory: String
    public var date: Date
    /// Cómo se pagó. `.cash` por default — el parser propone algo más
    /// específico cuando el texto lo menciona y se resuelve contra las
    /// tarjetas reales (`EntryModel.submit()`), no aquí.
    public var paymentMethod: PaymentMethod
    /// `nil` = gasto personal, el default. Si el texto mencionó con quién se
    /// dividió y eso se resolvió sin ambigüedad contra una lista compartida
    /// real (`SharedExpenseMatch.bestMatch`, `EntryModel.submit()`), estos
    /// tres campos quedan llenos — ADR-0025. Nunca se resuelven aquí en el
    /// `init`, mismo criterio que `paymentMethod`.
    public var sharedListID: SharedListID?
    public var payer: ParticipantID?
    public var split: SplitRule?
    public var needsReview: Bool
    /// De qué recurrente salió el movimiento, si salió de uno. Viaja con el
    /// borrador para que confirmarlo desde la bandeja no lo desligue: el
    /// recurrente se da por registrado justamente por este enlace (ADR-0042).
    public var recurringItemID: RecurringItemID?

    public init(
        id: ExpenseID = ExpenseID(),
        kind: Expense.Kind = .expense,
        amount: Decimal = 0,
        currency: Currency = .mxn,
        concept: String = "",
        category: String = "",
        subcategory: String = "",
        date: Date = Date(),
        paymentMethod: PaymentMethod = .cash,
        sharedListID: SharedListID? = nil,
        payer: ParticipantID? = nil,
        split: SplitRule? = nil,
        needsReview: Bool = false,
        recurringItemID: RecurringItemID? = nil) {
        self.recurringItemID = recurringItemID
        self.id = id
        self.kind = kind
        self.amount = amount
        self.currency = currency
        self.concept = concept
        self.category = category
        originalCategory = category
        self.subcategory = subcategory
        self.date = date
        self.paymentMethod = paymentMethod
        self.sharedListID = sharedListID
        self.payer = payer
        self.split = split
        self.needsReview = needsReview
    }

    /// Un movimiento ya guardado que vuelve a revisión (la bandeja de "Por
    /// revisar", rediseño sección 08). Conserva su `id` y todo lo que el
    /// borrador no edita, para que confirmarlo emita una corrección del mismo
    /// movimiento y no cree uno nuevo.
    public init(expense: Expense) {
        id = expense.id
        kind = expense.kind
        amount = expense.amount.amount
        currency = expense.amount.currency
        concept = expense.concept
        category = expense.category ?? ""
        originalCategory = expense.category ?? ""
        subcategory = expense.subcategory ?? ""
        date = expense.date
        paymentMethod = expense.paymentMethod ?? .cash
        sharedListID = expense.sharedListID
        payer = expense.payer
        split = expense.split
        needsReview = expense.needsReview
        recurringItemID = expense.recurringItemID
    }

    public init(result: ParseResult, fallbackDate: Date) {
        id = ExpenseID()
        recurringItemID = nil
        kind = result.kind
        amount = result.amount?.amount ?? 0
        currency = result.amount?.currency ?? .mxn
        concept = result.concept ?? ""
        category = result.category ?? ""
        originalCategory = result.category ?? ""
        subcategory = result.subcategory ?? ""
        date = result.date ?? fallbackDate
        paymentMethod = .cash
        sharedListID = nil
        payer = nil
        split = nil
        needsReview = result.needsReview
    }

    /// El desglose de cuánto le toca a cada quien con lo que hay ahora mismo
    /// en el formulario (ADR-0029) — se recalcula al editar el monto o el
    /// pagador, así el preview siempre refleja lo que se va a guardar.
    public var splitShares: [SplitShare] {
        asExpense().splitShares() ?? []
    }

    public func asExpense() -> Expense {
        Expense(
            id: id,
            kind: kind,
            amount: Money(amount: amount, currency: currency),
            concept: concept,
            // Solo los gastos se categorizan (Docs/CLAUDE.md) — el
            // selector de categoría ya se oculta para ingreso en
            // `DraftCard`, esto es lo que hace que ocultarlo no deje un
            // valor viejo guardado sin que se vea.
            category: kind == .expense && !category.isEmpty ? category : nil,
            subcategory: subcategory.isEmpty ? nil : subcategory,
            date: date,
            paymentMethod: paymentMethod,
            needsReview: needsReview,
            sharedListID: sharedListID,
            payer: payer,
            split: split,
            recurringItemID: recurringItemID)
    }
}

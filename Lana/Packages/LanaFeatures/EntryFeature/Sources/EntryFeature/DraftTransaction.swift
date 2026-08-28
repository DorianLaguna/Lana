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
    public var needsReview: Bool

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
        needsReview: Bool = false) {
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
        self.needsReview = needsReview
    }

    public init(result: ParseResult, fallbackDate: Date) {
        id = ExpenseID()
        kind = result.kind
        amount = result.amount?.amount ?? 0
        currency = result.amount?.currency ?? .mxn
        concept = result.concept ?? ""
        category = result.category ?? ""
        originalCategory = result.category ?? ""
        subcategory = result.subcategory ?? ""
        date = result.date ?? fallbackDate
        paymentMethod = .cash
        needsReview = result.needsReview
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
            needsReview: needsReview)
    }
}

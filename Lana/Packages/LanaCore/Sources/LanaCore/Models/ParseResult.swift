import Foundation

/// Cómo entendió el modelo que se pagó, tal cual lo dijo el texto — sin
/// resolver contra las tarjetas reales del usuario todavía (eso requiere
/// conocer sus `Card`, que `LanaParsing` no tiene). Quien arma el
/// `PaymentMethod` final (`EntryFeature`) hace ese segundo paso.
public enum PaymentMethodHint: String, Sendable, Hashable, CaseIterable {
    case cash
    case debit
    case credit
    case transfer
}

/// Lo que el parser extrajo de una frase en lenguaje natural, ya validado
/// (Fase 3: `AmountValidator`, filtro de monto ≤ 0, fuzzy match de
/// subcategoría — ADR-0011, ADR-0012).
public struct ParseResult: Sendable, Hashable {
    public var kind: Expense.Kind
    public var amount: Money?
    public var concept: String?
    public var category: String?
    /// Resuelta contra el vocabulario existente del usuario, o `nil` si el
    /// modelo no propuso nada específico (ADR-0011: "otro" nunca es válido aquí).
    public var subcategory: String?
    public var date: Date?
    /// `nil` si el texto no mencionó cómo se pagó.
    public var paymentMethodHint: PaymentMethodHint?
    /// El alias de tarjeta que mencionó el texto (p. ej. "la Nu"), sin
    /// resolver — `nil` si no mencionó ninguna.
    public var cardAliasHint: String?
    public var needsReview: Bool

    public init(
        kind: Expense.Kind = .expense,
        amount: Money? = nil,
        concept: String? = nil,
        category: String? = nil,
        subcategory: String? = nil,
        date: Date? = nil,
        paymentMethodHint: PaymentMethodHint? = nil,
        cardAliasHint: String? = nil,
        needsReview: Bool = true) {
        self.kind = kind
        self.amount = amount
        self.concept = concept
        self.category = category
        self.subcategory = subcategory
        self.date = date
        self.paymentMethodHint = paymentMethodHint
        self.cardAliasHint = cardAliasHint
        self.needsReview = needsReview
    }
}

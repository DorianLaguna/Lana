import Foundation

/// Vista de un `ExpenseAdded`/`IncomeAdded`/`CardPaymentRecorded` después de
/// aplicarle sus correcciones y de saber si fue anulado. Tipo interno del
/// ledger — no es un evento, es el resultado de plegarlos. `PersonLedger` y
/// `CardLedger` solo usan un subconjunto de estos campos; `ExpenseProjection`
/// los usa todos para reconstruir el `Expense` actual.
struct ResolvedTransaction: Sendable {
    enum Kind: Sendable {
        case expense
        case income
        case cardPayment
    }

    let id: EventID
    let kind: Kind
    let amount: Money
    let concept: String
    /// `nil` para ingresos y pagos de tarjeta — solo los gastos se categorizan.
    let category: String?
    let subcategory: String?
    let date: Date
    let paymentMethod: PaymentMethod?
    let sharedListID: SharedListID?
    let payer: ParticipantID?
    let split: SplitRule?
    /// Solo para `kind == .cardPayment`: a qué tarjeta se le pagó.
    let cardID: CardID?
    let needsReview: Bool
    let isVoided: Bool

    init(_ added: ExpenseAdded) {
        id = added.id
        kind = .expense
        amount = added.amount
        concept = added.concept
        category = added.category
        subcategory = added.subcategory
        date = added.date
        paymentMethod = added.paymentMethod
        sharedListID = added.sharedListID
        payer = added.payer
        split = added.split
        cardID = nil
        needsReview = added.needsReview
        isVoided = false
    }

    init(_ added: IncomeAdded) {
        id = added.id
        kind = .income
        amount = added.amount
        concept = added.concept
        category = nil
        subcategory = nil
        date = added.date
        paymentMethod = nil
        sharedListID = nil
        payer = nil
        split = nil
        cardID = nil
        needsReview = added.needsReview
        isVoided = false
    }

    init(_ payment: CardPaymentRecorded) {
        id = payment.id
        kind = .cardPayment
        amount = payment.amount
        concept = ""
        category = nil
        subcategory = nil
        date = payment.date
        paymentMethod = nil
        sharedListID = nil
        payer = nil
        split = nil
        cardID = payment.cardID
        needsReview = false
        isVoided = false
    }

    private init(
        id: EventID,
        kind: Kind,
        amount: Money,
        concept: String,
        category: String?,
        subcategory: String?,
        date: Date,
        paymentMethod: PaymentMethod?,
        sharedListID: SharedListID?,
        payer: ParticipantID?,
        split: SplitRule?,
        cardID: CardID?,
        needsReview: Bool,
        isVoided: Bool) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.concept = concept
        self.category = category
        self.subcategory = subcategory
        self.date = date
        self.paymentMethod = paymentMethod
        self.sharedListID = sharedListID
        self.payer = payer
        self.split = split
        self.cardID = cardID
        self.needsReview = needsReview
        self.isVoided = isVoided
    }

    func applying(_ correction: ExpenseCorrected) -> ResolvedTransaction {
        // `clearsSharedContext` gana sobre todo lo demás del bloque
        // compartido: es la única forma de expresar "vuélvelo personal",
        // porque `nil` en estos campos significa "conserva lo anterior"
        // (ADR-0027).
        let resolvedSharedListID = correction.clearsSharedContext ? nil : correction.sharedListID ?? sharedListID
        let resolvedPayer = correction.clearsSharedContext ? nil : correction.payer ?? payer
        let resolvedSplit = correction.clearsSharedContext ? nil : correction.split ?? split

        return ResolvedTransaction(
            id: id,
            kind: kind,
            amount: correction.amount ?? amount,
            concept: correction.concept ?? concept,
            category: correction.category ?? category,
            subcategory: correction.subcategory ?? subcategory,
            date: correction.date ?? date,
            paymentMethod: correction.paymentMethod ?? paymentMethod,
            sharedListID: resolvedSharedListID,
            payer: resolvedPayer,
            split: resolvedSplit,
            cardID: cardID,
            needsReview: correction.needsReview ?? needsReview,
            isVoided: isVoided)
    }

    func markedVoided() -> ResolvedTransaction {
        ResolvedTransaction(
            id: id,
            kind: kind,
            amount: amount,
            concept: concept,
            category: category,
            subcategory: subcategory,
            date: date,
            paymentMethod: paymentMethod,
            sharedListID: sharedListID,
            payer: payer,
            split: split,
            cardID: cardID,
            needsReview: needsReview,
            isVoided: true)
    }
}

/// Pliega un stream de eventos en su estado resuelto final. El resultado no
/// depende del orden del arreglo de entrada — las correcciones se aplican
/// ordenadas por `recordedAt` (y por `id` como desempate determinista),
/// nunca en el orden en que llegaron (ADR-0005).
enum LedgerFold {
    private struct Classified {
        var roots: [EventID: ResolvedTransaction] = [:]
        var corrections: [EventID: [ExpenseCorrected]] = [:]
        var voidedIDs: Set<EventID> = []
    }

    static func resolve(_ events: [ExpenseEvent]) -> [EventID: ResolvedTransaction] {
        var classified = classify(events)
        applyCorrections(&classified)
        applyVoids(&classified)
        return classified.roots
    }

    private static func classify(_ events: [ExpenseEvent]) -> Classified {
        var result = Classified()
        for event in events {
            switch event {
            case let .expenseAdded(added):
                result.roots[added.id] = ResolvedTransaction(added)
            case let .incomeAdded(added):
                result.roots[added.id] = ResolvedTransaction(added)
            case let .cardPaymentRecorded(payment):
                result.roots[payment.id] = ResolvedTransaction(payment)
            case let .expenseCorrected(correction):
                result.corrections[correction.correctsEventID, default: []].append(correction)
            case let .expenseVoided(void):
                result.voidedIDs.insert(void.voidsEventID)
            case .settlementRecorded:
                continue
            }
        }
        return result
    }

    private static func applyCorrections(_ classified: inout Classified) {
        for (targetID, targetCorrections) in classified.corrections {
            guard var resolved = classified.roots[targetID] else { continue }
            let ordered = targetCorrections.sorted {
                ($0.recordedAt, $0.id.rawValue.uuidString) < ($1.recordedAt, $1.id.rawValue.uuidString)
            }
            for correction in ordered {
                resolved = resolved.applying(correction)
            }
            classified.roots[targetID] = resolved
        }
    }

    private static func applyVoids(_ classified: inout Classified) {
        for id in classified.voidedIDs {
            if let existing = classified.roots[id] {
                classified.roots[id] = existing.markedVoided()
            }
        }
    }
}

import Foundation

/// Un gasto registrado. Personal si `sharedListID` es `nil`; de lista
/// compartida si trae `sharedListID`, `payer` y `split`.
public struct ExpenseAdded: Sendable, Hashable, Codable, Identifiable {
    public let id: EventID
    public let amount: Money
    public let exchangeRate: ExchangeRate?
    public let concept: String
    public let category: String
    /// Propiedad del usuario, resuelta por fuzzy match (ADR-0011).
    public let subcategory: String?
    public let date: Date
    public let paymentMethod: PaymentMethod
    public let sharedListID: SharedListID?
    public let payer: ParticipantID?
    public let split: SplitRule?
    /// Lo capturado automáticamente (Apple Pay, OCR de tickets) entra con
    /// `true` — nunca como dato confirmado (Docs/CLAUDE.md).
    public let needsReview: Bool
    public let recordedAt: Date

    public init(
        id: EventID = EventID(),
        amount: Money,
        exchangeRate: ExchangeRate? = nil,
        concept: String,
        category: String,
        subcategory: String? = nil,
        date: Date,
        paymentMethod: PaymentMethod,
        sharedListID: SharedListID? = nil,
        payer: ParticipantID? = nil,
        split: SplitRule? = nil,
        needsReview: Bool = false,
        recordedAt: Date = Date()) {
        self.id = id
        self.amount = amount
        self.exchangeRate = exchangeRate
        self.concept = concept
        self.category = category
        self.subcategory = subcategory
        self.date = date
        self.paymentMethod = paymentMethod
        self.sharedListID = sharedListID
        self.payer = payer
        self.split = split
        self.needsReview = needsReview
        self.recordedAt = recordedAt
    }
}

/// Un ingreso registrado.
public struct IncomeAdded: Sendable, Hashable, Codable, Identifiable {
    public let id: EventID
    public let amount: Money
    public let exchangeRate: ExchangeRate?
    public let concept: String
    public let date: Date
    public let needsReview: Bool
    public let recordedAt: Date

    public init(
        id: EventID = EventID(),
        amount: Money,
        exchangeRate: ExchangeRate? = nil,
        concept: String,
        date: Date,
        needsReview: Bool = false,
        recordedAt: Date = Date()) {
        self.id = id
        self.amount = amount
        self.exchangeRate = exchangeRate
        self.concept = concept
        self.date = date
        self.needsReview = needsReview
        self.recordedAt = recordedAt
    }
}

/// Corrige uno o más campos de un `ExpenseAdded` o `IncomeAdded` previo. Solo
/// los campos que cambiaron llevan valor — el resto es `nil` y el ledger
/// conserva el valor anterior. Editar nunca muta el evento original
/// (Docs/CLAUDE.md): esto es un evento nuevo que lo referencia.
public struct ExpenseCorrected: Sendable, Hashable, Codable, Identifiable {
    public let id: EventID
    public let correctsEventID: EventID
    public let amount: Money?
    public let concept: String?
    public let category: String?
    public let subcategory: String?
    public let date: Date?
    public let paymentMethod: PaymentMethod?
    public let needsReview: Bool?
    public let recordedAt: Date

    public init(
        id: EventID = EventID(),
        correctsEventID: EventID,
        amount: Money? = nil,
        concept: String? = nil,
        category: String? = nil,
        subcategory: String? = nil,
        date: Date? = nil,
        paymentMethod: PaymentMethod? = nil,
        needsReview: Bool? = nil,
        recordedAt: Date = Date()) {
        self.id = id
        self.correctsEventID = correctsEventID
        self.amount = amount
        self.concept = concept
        self.category = category
        self.subcategory = subcategory
        self.date = date
        self.paymentMethod = paymentMethod
        self.needsReview = needsReview
        self.recordedAt = recordedAt
    }
}

/// Anula un `ExpenseAdded` o `IncomeAdded` previo. Borrar nunca elimina el
/// evento original — lo anula con un evento nuevo (Docs/CLAUDE.md).
public struct ExpenseVoided: Sendable, Hashable, Codable, Identifiable {
    public let id: EventID
    public let voidsEventID: EventID
    public let recordedAt: Date

    public init(id: EventID = EventID(), voidsEventID: EventID, recordedAt: Date = Date()) {
        self.id = id
        self.voidsEventID = voidsEventID
        self.recordedAt = recordedAt
    }
}

/// Registra que `from` le pagó `amount` a `to` para saldar (parte de) su
/// deuda en `sharedListID`.
public struct SettlementRecorded: Sendable, Hashable, Codable, Identifiable {
    public let id: EventID
    public let sharedListID: SharedListID
    public let from: ParticipantID
    public let to: ParticipantID
    public let amount: Money
    public let paymentMethod: PaymentMethod
    public let date: Date
    public let recordedAt: Date

    public init(
        id: EventID = EventID(),
        sharedListID: SharedListID,
        from: ParticipantID,
        to: ParticipantID,
        amount: Money,
        paymentMethod: PaymentMethod,
        date: Date,
        recordedAt: Date = Date()) {
        self.id = id
        self.sharedListID = sharedListID
        self.from = from
        self.to = to
        self.amount = amount
        self.paymentMethod = paymentMethod
        self.date = date
        self.recordedAt = recordedAt
    }
}

/// Registra un pago hecho a una tarjeta de crédito. **No es un gasto** —
/// contarlo como tal duplicaría el cargo original (Docs/DATA-FLOW.md). Se
/// usa para saber cuánto queda pendiente del último estado de cuenta
/// (`CardLedger.outstandingStatementBalance`).
public struct CardPaymentRecorded: Sendable, Hashable, Codable, Identifiable {
    public let id: EventID
    public let cardID: CardID
    public let amount: Money
    public let date: Date
    public let recordedAt: Date

    public init(
        id: EventID = EventID(),
        cardID: CardID,
        amount: Money,
        date: Date,
        recordedAt: Date = Date()) {
        self.id = id
        self.cardID = cardID
        self.amount = amount
        self.date = date
        self.recordedAt = recordedAt
    }
}

/// Un evento inmutable del ledger. Los eventos conmutan: el orden en que se
/// pliegan no altera el estado final (ADR-0005) — importante porque dos
/// devices pueden sincronizar en cualquier orden.
public enum ExpenseEvent: Sendable, Hashable, Codable, Identifiable {
    case expenseAdded(ExpenseAdded)
    case incomeAdded(IncomeAdded)
    case expenseCorrected(ExpenseCorrected)
    case expenseVoided(ExpenseVoided)
    case settlementRecorded(SettlementRecorded)
    case cardPaymentRecorded(CardPaymentRecorded)

    public var id: EventID {
        switch self {
        case let .expenseAdded(event): event.id
        case let .incomeAdded(event): event.id
        case let .expenseCorrected(event): event.id
        case let .expenseVoided(event): event.id
        case let .settlementRecorded(event): event.id
        case let .cardPaymentRecorded(event): event.id
        }
    }

    public var recordedAt: Date {
        switch self {
        case let .expenseAdded(event): event.recordedAt
        case let .incomeAdded(event): event.recordedAt
        case let .expenseCorrected(event): event.recordedAt
        case let .expenseVoided(event): event.recordedAt
        case let .settlementRecorded(event): event.recordedAt
        case let .cardPaymentRecorded(event): event.recordedAt
        }
    }
}

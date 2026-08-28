import Foundation
import LanaCore
import Observation

/// Cuánto se gastó en una categoría, dentro del drill-down de una forma de
/// pago (`PaymentMethodDetailView`).
public struct CategoryWithinPaymentMethodTotal: Identifiable, Sendable {
    public var id: String {
        category
    }

    public let category: String
    public let amount: Decimal
    public let currency: Currency
}

/// Cuánto se gastó con una tarjeta específica, dentro del drill-down de
/// "crédito" o "débito" — sin esto, las dos formas de pago que sí
/// distinguen tarjeta (a diferencia de efectivo/transferencia) se veían
/// igual de genéricas que las que no, y no había forma de saber con cuál
/// tarjeta se pagó cada cosa (pedido explícito del usuario).
public struct CardWithinPaymentMethodTotal: Identifiable, Sendable {
    public var id: CardID {
        cardID
    }

    public let cardID: CardID
    public let alias: String
    public let amount: Decimal
    public let currency: Currency
}

/// El drill-down de una forma de pago del mes: total, desglose por
/// categoría y las transacciones pagadas así, agrupadas por día — mismo
/// patrón que `CategoryDetailModel`, filtrando por cómo se pagó en vez de
/// por categoría. Antes, tocar una rebanada de "Por forma de pago" en el
/// Dashboard no hacía nada (el callback de tap estaba vacío) — este modelo
/// es lo que faltaba para que ese drill-down exista de verdad.
@MainActor
@Observable
public final class PaymentMethodDetailModel {
    /// La forma de pago que se está viendo ("efectivo", "crédito"...) —
    /// mismas etiquetas que `DashboardModel.paymentMethodTotals`.
    public let label: String
    /// Los gastos pagados así, dentro del mes.
    public private(set) var expenses: [Expense] = []
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar.
    public private(set) var errorMessage: String?
    /// Las tarjetas guardadas — para resolver alias en `cardTotals`.
    public private(set) var cards: [Card] = []

    private let store: any ExpenseStore
    private let cardStore: any CardStore
    private let month: Date
    private let calendar: Calendar

    /// - Parameters:
    ///   - label: la forma de pago a filtrar (ya como etiqueta, no `PaymentMethod`).
    ///   - store: de dónde se leen las transacciones.
    ///   - cardStore: de dónde se leen las tarjetas, para mostrar con cuál se pagó cada cosa.
    ///   - month: el mes que ya se está viendo en el dashboard.
    public init(
        label: String,
        store: any ExpenseStore,
        cardStore: any CardStore,
        month: Date,
        calendar: Calendar = .current) {
        self.label = label
        self.store = store
        self.cardStore = cardStore
        self.month = month
        self.calendar = calendar
    }

    /// Carga los gastos pagados con esta forma de pago. Se llama cuando la
    /// pantalla aparece.
    public func onAppear() async {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return }
        // Mismo ajuste que `DashboardModel.load()`: el `end` de
        // `dateInterval(of: .month)` es la medianoche del mes siguiente.
        let range = DateInterval(start: monthInterval.start, end: monthInterval.end.addingTimeInterval(-1))
        isLoading = true
        errorMessage = nil
        do {
            let all = try await store.expenses(in: range)
            expenses = all
                .filter { $0.kind == .expense && DashboardModel.paymentMethodLabel($0.paymentMethod) == label }
            cards = try await cardStore.cards()
        } catch {
            errorMessage = error.localizedDescription
            expenses = []
        }
        isLoading = false
    }

    /// Cuánto se gastó en total, con esta forma de pago, este mes.
    public var total: Decimal {
        expenses.reduce(0) { $0 + $1.amount.amount }
    }

    /// La moneda de los gastos de esta forma de pago — `.mxn` si no hay ninguno.
    public var currency: Currency {
        expenses.first?.amount.currency ?? .mxn
    }

    /// El desglose por categoría, de mayor a menor.
    public var categoryTotals: [CategoryWithinPaymentMethodTotal] {
        var totals: [String: Decimal] = [:]
        for expense in expenses {
            totals[expense.category ?? "otro", default: 0] += expense.amount.amount
        }
        return totals
            .map { CategoryWithinPaymentMethodTotal(category: $0.key, amount: $0.value, currency: currency) }
            .sorted { $0.amount > $1.amount }
    }

    /// Los gastos de esta forma de pago, agrupados por día.
    public var daySections: [DaySection] {
        expenses.groupedByDay(calendar: calendar)
    }

    /// El desglose por tarjeta, de mayor a menor — vacío para "efectivo" y
    /// "transferencia", que no llevan tarjeta.
    public var cardTotals: [CardWithinPaymentMethodTotal] {
        var totals: [CardID: Decimal] = [:]
        for expense in expenses {
            guard let cardID = Self.cardID(from: expense.paymentMethod) else { continue }
            totals[cardID, default: 0] += expense.amount.amount
        }
        let aliasesByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.alias) })
        return totals
            .map { cardID, amount in
                CardWithinPaymentMethodTotal(
                    cardID: cardID,
                    alias: aliasesByID[cardID] ?? "Tarjeta borrada",
                    amount: amount,
                    currency: currency)
            }
            .sorted { $0.amount > $1.amount }
    }

    private static func cardID(from method: PaymentMethod?) -> CardID? {
        switch method {
        case let .credit(cardID), let .debit(cardID):
            cardID
        case .cash, .transfer, nil:
            nil
        }
    }
}

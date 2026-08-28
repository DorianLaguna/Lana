import Foundation
import LanaCore
import Observation

/// El total del mes, separado por moneda — nunca se suman montos de
/// monedas distintas (Docs/CONVENTIONS.md → Multi-moneda).
public struct MonthTotal: Identifiable, Sendable {
    public var id: Currency {
        currency
    }

    public let currency: Currency
    public let expenses: Decimal
    public let income: Decimal
}

/// Toda la lógica y el estado del dashboard mensual. La vista no decide
/// nada — solo refleja estas propiedades derivadas y llama a
/// `goToPreviousMonth`/`goToNextMonth` (Docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class DashboardModel {
    /// El primer día del mes que se muestra.
    public private(set) var month: Date
    /// Todo lo cargado del mes vigente — gastos e ingresos juntos.
    public private(set) var expenses: [Expense] = []
    /// `true` mientras se está cargando el mes.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar.
    public private(set) var errorMessage: String?

    private let store: any ExpenseStore
    private let vocabularyStore: any CorrectionVocabularyStore
    private let cardStore: any CardStore
    private let calendar: Calendar

    /// - Parameters:
    ///   - store: de dónde se leen las transacciones.
    ///   - vocabularyStore: dónde se registra una corrección de categoría
    ///     al editar un gasto ya guardado.
    ///   - cardStore: de dónde se leen las tarjetas, para el drill-down de
    ///     "Por forma de pago" — saber con cuál tarjeta se pagó cada cosa.
    ///   - referenceDate: qué mes mostrar al aparecer. Por defecto, hoy.
    public init(
        store: any ExpenseStore,
        vocabularyStore: any CorrectionVocabularyStore,
        cardStore: any CardStore,
        referenceDate: Date = Date(),
        calendar: Calendar = .current) {
        self.store = store
        self.vocabularyStore = vocabularyStore
        self.cardStore = cardStore
        self.calendar = calendar
        month = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
    }

    /// Carga el mes vigente. Se llama cuando la pantalla aparece.
    public func onAppear() async {
        await load()
    }

    /// El drill-down de una categoría, para el mes que ya se está viendo
    /// (Fase 6.5) — `store` se queda encapsulado en `DashboardModel`, la
    /// vista nunca lo toca directo.
    public func makeCategoryDetailModel(for category: String) -> CategoryDetailModel {
        CategoryDetailModel(category: category, store: store, month: month, calendar: calendar)
    }

    /// El drill-down de una forma de pago (Fase 6.5) — antes tocar una
    /// rebanada de "Por forma de pago" no llevaba a ningún lado (el tap
    /// callback estaba vacío, `CategoryBreakdownChart(...) { _ in }`).
    public func makePaymentMethodDetailModel(for label: String) -> PaymentMethodDetailModel {
        PaymentMethodDetailModel(label: label, store: store, cardStore: cardStore, month: month, calendar: calendar)
    }

    /// Editar un gasto/ingreso ya guardado — hasta ahora no había forma de
    /// llegar aquí desde el Dashboard, así que la promesa de Ajustes ("Lana
    /// aprende de tus correcciones") nunca se cumplía: no había nada que
    /// corregir después de capturar.
    public func makeEditExpenseModel(for expense: Expense) -> EditExpenseModel {
        EditExpenseModel(expense: expense, store: store, vocabularyStore: vocabularyStore)
    }

    /// "Navegación entre meses" (Docs/PLAN.md → Fase 6).
    public func goToPreviousMonth() async {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: month) else { return }
        month = previous
        await load()
    }

    /// "Navegación entre meses" (Docs/PLAN.md → Fase 6).
    public func goToNextMonth() async {
        guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { return }
        month = next
        await load()
    }

    private func load() async {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return }
        // `DateInterval.contains` incluye ambos extremos, y el `end` de
        // `dateInterval(of: .month)` es la medianoche del mes siguiente — sin
        // este ajuste, un gasto exactamente a esa medianoche contaría en dos
        // meses a la vez.
        let range = DateInterval(start: monthInterval.start, end: monthInterval.end.addingTimeInterval(-1))
        isLoading = true
        errorMessage = nil
        do {
            expenses = try await store.expenses(in: range)
        } catch {
            errorMessage = error.localizedDescription
            expenses = []
        }
        isLoading = false
    }

    /// Agrupadas por día, el día más reciente primero.
    public var daySections: [DaySection] {
        expenses.groupedByDay(calendar: calendar)
    }

    /// El total del mes, por moneda.
    public var monthTotals: [MonthTotal] {
        var expensesByCurrency: [Currency: Decimal] = [:]
        var incomeByCurrency: [Currency: Decimal] = [:]
        for expense in expenses {
            switch expense.kind {
            case .expense:
                expensesByCurrency[expense.amount.currency, default: 0] += expense.amount.amount
            case .income:
                incomeByCurrency[expense.amount.currency, default: 0] += expense.amount.amount
            }
        }
        let currencies = Set(expensesByCurrency.keys).union(incomeByCurrency.keys)
        return currencies
            .map { currency in
                MonthTotal(
                    currency: currency,
                    expenses: expensesByCurrency[currency] ?? 0,
                    income: incomeByCurrency[currency] ?? 0)
            }
            .sorted { $0.currency.rawValue < $1.currency.rawValue }
    }

    /// El desglose por categoría, por moneda — para la gráfica.
    public var categoryTotals: [CategoryTotal] {
        var totals: [Currency: [String: Decimal]] = [:]
        for expense in expenses where expense.kind == .expense {
            let category = expense.category ?? "otro"
            totals[expense.amount.currency, default: [:]][category, default: 0] += expense.amount.amount
        }
        return totals
            .flatMap { currency, byCategory in
                byCategory.map { category, amount in
                    CategoryTotal(category: category, amount: amount, currency: currency)
                }
            }
            .sorted { $0.amount > $1.amount }
    }

    /// El desglose por categoría de una sola moneda — para la dona de
    /// "cuánto sobra" (`RemainingDonutChart`), que necesita las categorías
    /// de una sola moneda a la vez para que sus proporciones tengan
    /// sentido contra el ingreso de esa misma moneda.
    public func categoryTotals(in currency: Currency) -> [CategoryTotal] {
        categoryTotals.filter { $0.currency == currency }
    }

    /// Lo que quedó ambiguo y necesita que el usuario lo revise.
    public var needsReviewItems: [Expense] {
        expenses.filter(\.needsReview).sorted { $0.date > $1.date }
    }

    /// El desglose del mes por forma de pago (efectivo, débito, crédito,
    /// transferencia) — solo gastos, igual que `categoryTotals`; un ingreso
    /// no se "paga" con nada. No distingue tarjeta por tarjeta, solo el
    /// tipo — cruzar eso con `CardStore` es más de lo que se pidió aquí.
    public var paymentMethodTotals: [CategoryTotal] {
        var totals: [Currency: [String: Decimal]] = [:]
        for expense in expenses where expense.kind == .expense {
            let label = Self.paymentMethodLabel(expense.paymentMethod)
            totals[expense.amount.currency, default: [:]][label, default: 0] += expense.amount.amount
        }
        return totals
            .flatMap { currency, byLabel in
                byLabel.map { label, amount in CategoryTotal(category: label, amount: amount, currency: currency) }
            }
            .sorted { $0.amount > $1.amount }
    }

    /// `internal`, no `private` — `PaymentMethodDetailModel` (mismo target)
    /// necesita filtrar con exactamente esta misma regla de agrupación.
    static func paymentMethodLabel(_ method: PaymentMethod?) -> String {
        switch method {
        case .cash, nil: "efectivo"
        case .debit: "débito"
        case .credit: "crédito"
        case .transfer: "transferencia"
        }
    }
}

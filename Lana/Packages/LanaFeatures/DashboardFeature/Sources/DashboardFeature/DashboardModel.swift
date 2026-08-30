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
    private let sharedListStore: any SharedListStore
    /// No `private` — `CategoryDetailModel`/`PaymentMethodDetailModel`
    /// (mismo target) lo necesitan para `daySections` sobre los gastos que
    /// derivan de este mismo modelo, sin guardar su propia copia (ver el
    /// comment de esos tipos para el porqué).
    let calendar: Calendar
    /// Qué participante es "yo" en cada lista compartida — cacheado aquí
    /// tras cargar el mes, para no volver a llamar al store (async) cada
    /// vez que se suma un gasto (`Expense.personalAmount`, ADR-0022). Se lee
    /// también desde `DashboardView` para pasarlo a `DaySectionListView`.
    public private(set) var viewerIdentities: [SharedListID: ParticipantID] = [:]

    /// - Parameters:
    ///   - store: de dónde se leen las transacciones.
    ///   - vocabularyStore: dónde se registra una corrección de categoría
    ///     al editar un gasto ya guardado.
    ///   - cardStore: de dónde se leen las tarjetas, para el drill-down de
    ///     "Por forma de pago" — saber con cuál tarjeta se pagó cada cosa.
    ///   - sharedListStore: de dónde se lee qué participante de una lista
    ///     compartida es "yo", para sumar la parte real de un gasto
    ///     compartido y no el total (`Expense.personalAmount`).
    ///   - referenceDate: qué mes mostrar al aparecer. Por defecto, hoy.
    public init(
        store: any ExpenseStore,
        vocabularyStore: any CorrectionVocabularyStore,
        cardStore: any CardStore,
        sharedListStore: any SharedListStore,
        referenceDate: Date = Date(),
        calendar: Calendar = .current) {
        self.store = store
        self.vocabularyStore = vocabularyStore
        self.cardStore = cardStore
        self.sharedListStore = sharedListStore
        self.calendar = calendar
        month = calendar.dateInterval(of: .month, for: referenceDate)?.start ?? referenceDate
    }

    /// Carga el mes vigente. Se llama cuando la pantalla aparece.
    public func onAppear() async {
        await load()
    }

    /// El drill-down de una categoría, para el mes que ya se está viendo
    /// (Fase 6.5). Deriva sus gastos de este mismo modelo en vez de
    /// cargar su propia copia — antes tenía su propio `onAppear()` que
    /// leía el store por separado, y editar o borrar un gasto desde ese
    /// drill-down lo quitaba de aquí pero la copia aparte del drill-down se
    /// quedaba vieja hasta salir y volver a entrar (el bug real detrás de
    /// "dice que no hay ningún registro" justo después de guardar). Al
    /// derivar en vivo de `expenses`, no hay una segunda copia que se pueda
    /// desincronizar.
    public func makeCategoryDetailModel(for category: String) -> CategoryDetailModel {
        CategoryDetailModel(category: category, dashboard: self)
    }

    /// El drill-down de una forma de pago (Fase 6.5) — antes tocar una
    /// rebanada de "Por forma de pago" no llevaba a ningún lado (el tap
    /// callback estaba vacío, `CategoryBreakdownChart(...) { _ in }`).
    /// Mismo principio que `makeCategoryDetailModel`: deriva sus gastos de
    /// aquí, `cardStore` es lo único que sigue siendo suyo (la lista de
    /// tarjetas no vive en `DashboardModel`).
    public func makePaymentMethodDetailModel(for label: String) -> PaymentMethodDetailModel {
        PaymentMethodDetailModel(label: label, dashboard: self, cardStore: cardStore)
    }

    /// Editar un gasto/ingreso ya guardado — hasta ahora no había forma de
    /// llegar aquí desde el Dashboard, así que la promesa de Ajustes ("Lana
    /// aprende de tus correcciones") nunca se cumplía: no había nada que
    /// corregir después de capturar.
    public func makeEditExpenseModel(for expense: Expense) -> EditExpenseModel {
        EditExpenseModel(
            expense: expense,
            store: store,
            vocabularyStore: vocabularyStore,
            sharedListStore: sharedListStore)
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
            viewerIdentities = await Self.loadViewerIdentities(for: expenses, from: sharedListStore)
        } catch {
            errorMessage = error.localizedDescription
            expenses = []
        }
        isLoading = false
    }

    /// `internal`, no `private` — `CategoryDetailModel`/`PaymentMethodDetailModel`
    /// (mismo target) hacen exactamente esta misma resolución sobre su
    /// propio subconjunto de gastos.
    static func loadViewerIdentities(
        for expenses: [Expense],
        from sharedListStore: any SharedListStore) async -> [SharedListID: ParticipantID] {
        await loadViewerIdentities(
            for: Array(Set(expenses.compactMap(\.sharedListID))),
            from: sharedListStore)
    }

    /// Igual que la de arriba, pero partiendo de los ids directamente —
    /// `EditExpenseModel` los necesita para todas las listas del usuario,
    /// no solo las presentes en un conjunto de gastos (ADR-0027).
    static func loadViewerIdentities(
        for sharedListIDs: [SharedListID],
        from sharedListStore: any SharedListStore) async -> [SharedListID: ParticipantID] {
        var identities: [SharedListID: ParticipantID] = [:]
        for sharedListID in Set(sharedListIDs) {
            if let viewerID = try? await sharedListStore.viewerParticipantID(for: sharedListID) {
                identities[sharedListID] = viewerID
            }
        }
        return identities
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
                let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
                expensesByCurrency[personal.currency, default: 0] += personal.amount
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
            let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
            totals[personal.currency, default: [:]][category, default: 0] += personal.amount
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
            let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
            totals[personal.currency, default: [:]][label, default: 0] += personal.amount
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

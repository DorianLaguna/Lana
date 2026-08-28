import Foundation
import LanaCore
import Observation

/// Cuánto se gastó en una subcategoría, dentro del drill-down de una
/// categoría (`CategoryDetailView`).
public struct SubcategoryTotal: Identifiable, Sendable {
    public var id: String {
        subcategory
    }

    public let subcategory: String
    public let amount: Decimal
    public let currency: Currency
}

/// El drill-down de una categoría del mes: total, desglose por subcategoría
/// y las transacciones de esa categoría, agrupadas por día (Fase 6.5, calca
/// `CategoriaDetalle.dc.html`). La vista no decide nada — solo refleja esto
/// (Docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class CategoryDetailModel {
    /// La categoría que se está viendo.
    public let category: String
    /// Los gastos de esta categoría, dentro del mes.
    public private(set) var expenses: [Expense] = []
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar.
    public private(set) var errorMessage: String?

    private let store: any ExpenseStore
    private let month: Date
    private let calendar: Calendar

    /// - Parameters:
    ///   - category: la categoría a filtrar.
    ///   - store: de dónde se leen las transacciones.
    ///   - month: el mes que ya se está viendo en el dashboard.
    public init(category: String, store: any ExpenseStore, month: Date, calendar: Calendar = .current) {
        self.category = category
        self.store = store
        self.month = month
        self.calendar = calendar
    }

    /// Carga los gastos de esta categoría. Se llama cuando la pantalla aparece.
    public func onAppear() async {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return }
        // Mismo ajuste que `DashboardModel.load()`: el `end` de
        // `dateInterval(of: .month)` es la medianoche del mes siguiente.
        let range = DateInterval(start: monthInterval.start, end: monthInterval.end.addingTimeInterval(-1))
        isLoading = true
        errorMessage = nil
        do {
            let all = try await store.expenses(in: range)
            expenses = all.filter { $0.kind == .expense && ($0.category ?? "otro") == category }
        } catch {
            errorMessage = error.localizedDescription
            expenses = []
        }
        isLoading = false
    }

    /// Cuánto se gastó en total, en esta categoría, este mes.
    public var total: Decimal {
        expenses.reduce(0) { $0 + $1.amount.amount }
    }

    /// La moneda de los gastos de esta categoría — `.mxn` si no hay ninguno.
    public var currency: Currency {
        expenses.first?.amount.currency ?? .mxn
    }

    /// El desglose por subcategoría, de mayor a menor.
    public var subcategoryTotals: [SubcategoryTotal] {
        var totals: [String: Decimal] = [:]
        for expense in expenses {
            totals[expense.subcategory ?? "otro", default: 0] += expense.amount.amount
        }
        return totals
            .map { SubcategoryTotal(subcategory: $0.key, amount: $0.value, currency: currency) }
            .sorted { $0.amount > $1.amount }
    }

    /// Los gastos de esta categoría, agrupados por día.
    public var daySections: [DaySection] {
        expenses.groupedByDay(calendar: calendar)
    }
}

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
///
/// Deriva todo de `DashboardModel.expenses` en vez de cargar su propia
/// copia — antes tenía un `onAppear()` que releía el store por separado, y
/// esa copia solo se refrescaba si alguien se acordaba de llamarlo nuevo
/// después de editar o borrar. En la práctica nunca era el momento correcto
/// (SwiftUI reconstruye este modelo cuando `DashboardView` se vuelve a
/// dibujar, así que un refresco explícito llamado justo después podía
/// terminar operando sobre una instancia ya reemplazada) — el bug real
/// detrás de "guardé el cambio y dice que no hay ningún registro". Sin una
/// segunda copia, no hay nada que quede desincronizado: en cuanto
/// `DashboardModel.expenses` se actualiza, este drill-down se actualiza
/// solo.
@MainActor
@Observable
public final class CategoryDetailModel {
    /// La categoría que se está viendo.
    public let category: String
    private let source: any ExpenseProviding

    /// - Parameters:
    ///   - category: la categoría a filtrar.
    ///   - source: de dónde salen los gastos del periodo vigente — el mismo
    ///     modelo que ya está en pantalla, nunca una copia propia. Es el
    ///     Dashboard cuando se entra desde el mes y la vista anual cuando se
    ///     entra desde el año; el drill-down es el mismo.
    init(category: String, source: any ExpenseProviding) {
        self.category = category
        self.source = source
    }

    /// Los gastos de esta categoría, dentro del periodo.
    public var expenses: [Expense] {
        source.expenses.filter { $0.kind == .expense && ($0.category ?? "otro") == category }
    }

    /// Ver el mismo campo en el modelo del que deriva — nunca su propia copia.
    public var viewerIdentities: [SharedListID: ParticipantID] {
        source.viewerIdentities
    }

    /// Cuánto se gastó en total, en esta categoría, en el periodo — la parte
    /// real de quien mira, no el total de un gasto compartido
    /// (`Expense.personalAmount`).
    public var total: Decimal {
        expenses.reduce(0) { $0 + $1.personalAmount(viewerIdentities: viewerIdentities).amount }
    }

    /// La moneda de los gastos de esta categoría — `.mxn` si no hay ninguno.
    public var currency: Currency {
        expenses.first?.amount.currency ?? .mxn
    }

    /// El desglose por subcategoría, de mayor a menor.
    public var subcategoryTotals: [SubcategoryTotal] {
        var totals: [String: Decimal] = [:]
        for expense in expenses {
            let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
            totals[expense.subcategory ?? "otro", default: 0] += personal.amount
        }
        return totals
            .map { SubcategoryTotal(subcategory: $0.key, amount: $0.value, currency: currency) }
            .sorted { $0.amount > $1.amount }
    }

    /// Los gastos de esta categoría, agrupados por día.
    public var daySections: [DaySection] {
        expenses.groupedByDay(calendar: source.calendar)
    }
}

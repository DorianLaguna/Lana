import Foundation

/// Un mes con sus transacciones, ya ordenadas. El equivalente de `DaySection`
/// un nivel arriba, para la vista anual.
public struct MonthSection: Identifiable, Sendable {
    public var id: Date {
        month
    }

    /// El primer día del mes, a medianoche.
    public let month: Date
    public let items: [Expense]

    public init(month: Date, items: [Expense]) {
        self.month = month
        self.items = items
    }
}

public extension [Expense] {
    /// Agrupa por mes, el mes más reciente primero, y cada mes con sus
    /// transacciones ordenadas de más reciente a más antigua. Calcado de
    /// `groupedByDay(calendar:)`.
    ///
    /// Los meses sin ningún movimiento no aparecen — quien necesite una serie
    /// continua de doce puntos (la gráfica anual) la arma con
    /// `AnnualStatistics.monthlyPoints(in:)`, que sí rellena los huecos.
    func groupedByMonth(calendar: Calendar = .current) -> [MonthSection] {
        let grouped = Dictionary(grouping: self) { expense in
            calendar.dateInterval(of: .month, for: expense.date)?.start ?? calendar.startOfDay(for: expense.date)
        }
        return grouped
            .map { month, items in
                MonthSection(month: month, items: items.sorted { $0.date > $1.date })
            }
            .sorted { $0.month > $1.month }
    }
}

import Foundation

/// Un día con sus transacciones, ya ordenadas para una lista agrupada.
/// Vive en `LanaCore` (y no en `DashboardFeature`, donde nació) porque el
/// drill-down por categoría y el detalle de tarjeta lo necesitan igual, y
/// las features no pueden importarse entre sí (Docs/ARCHITECTURE.md).
public struct DaySection: Identifiable, Sendable {
    public var id: Date {
        day
    }

    public let day: Date
    public let items: [Expense]

    public init(day: Date, items: [Expense]) {
        self.day = day
        self.items = items
    }
}

public extension [Expense] {
    /// Agrupa por día, el día más reciente primero, y cada día con sus
    /// transacciones ordenadas de más reciente a más antigua.
    func groupedByDay(calendar: Calendar = .current) -> [DaySection] {
        let grouped = Dictionary(grouping: self) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { day, items in
                DaySection(day: day, items: items.sorted { $0.date > $1.date })
            }
            .sorted { $0.day > $1.day }
    }
}

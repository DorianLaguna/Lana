import Foundation

/// El intervalo de un ciclo de corte: `(start, end]` — excluye el día del
/// corte anterior, incluye el día de corte de este ciclo. Público porque
/// `CardsFeature` (Fase 6.5) también necesita este rango para pedirle a
/// `ExpenseStore.expenses(in:)` los cargos del ciclo vigente, sin duplicar
/// esta cuenta (que ya resuelve el caso de un corte que no existe en un mes
/// corto).
public struct StatementCycle: Sendable {
    public let start: Date
    public let end: Date

    public func contains(_ date: Date) -> Bool {
        date > start && date <= end
    }

    /// El ciclo que contiene `date` para una tarjeta con este `cutoffDay`.
    /// Si el día de corte no existe en un mes (p. ej. 31 en febrero), se usa
    /// el último día de ese mes.
    public static func containing(_ date: Date, cutoffDay: Int, calendar: Calendar) -> StatementCycle {
        let thisMonthCutoff = cutoffDate(near: date, cutoffDay: cutoffDay, calendar: calendar, monthOffset: 0)
        if date <= thisMonthCutoff {
            let previous = cutoffDate(near: date, cutoffDay: cutoffDay, calendar: calendar, monthOffset: -1)
            return StatementCycle(start: previous, end: thisMonthCutoff)
        } else {
            let next = cutoffDate(near: date, cutoffDay: cutoffDay, calendar: calendar, monthOffset: 1)
            return StatementCycle(start: thisMonthCutoff, end: next)
        }
    }

    private static func cutoffDate(near date: Date, cutoffDay: Int, calendar: Calendar, monthOffset: Int) -> Date {
        let referenceDate = calendar.date(byAdding: .month, value: monthOffset, to: date) ?? date
        var components = calendar.dateComponents([.year, .month], from: referenceDate)
        let daysInMonth = calendar.range(of: .day, in: .month, for: referenceDate)?.count ?? 28
        components.day = min(cutoffDay, daysInMonth)
        guard let cutoff = calendar.date(from: components) else { return referenceDate }
        return calendar.startOfDay(for: cutoff)
    }
}

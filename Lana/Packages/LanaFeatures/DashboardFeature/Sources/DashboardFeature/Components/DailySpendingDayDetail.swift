import LanaCore
import LanaDesign
import SwiftUI

/// Lo que se abre al tocar un día en "Día a día": "Lunes 14 · $2,200", con
/// qué cerrarlo, los gastos de ese día con el mismo filtro de la gráfica y,
/// si ese día cae un recurrente que todavía no se cobra, cuál.
struct DailySpendingDayDetail: View {
    @Environment(\.lana) private var lana
    let model: DashboardModel
    let day: Int
    let data: DailySpending
    let excludingRecurring: Bool
    let onClose: () -> Void
    /// Tocar un gasto lo abre para editar, como en el resto de Mes.
    let onSelectExpense: (Expense) -> Void

    var body: some View {
        let items = day <= data.lastDay ? model.expenses(onDay: day, excludingRecurring: excludingRecurring) : []
        let upcoming = data.upcomingRecurring.filter { model.calendar.component(.day, from: $0.date) == day }
        let nextMonth = data.upcomingNextMonthRecurring
            .filter { model.calendar.component(.day, from: $0.date) == day }
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            header
            if items.isEmpty, upcoming.isEmpty, nextMonth.isEmpty {
                Text(day > data.lastDay ? "Ese día todavía no llega." : "No registraste gastos ese día.")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
            }
            if !items.isEmpty {
                MovementRows(
                    expenses: items,
                    source: model,
                    highlightedIDs: model.highlightedExpenseIDs,
                    deferredLabel: model.deferredLabel(for:),
                    onSelect: onSelectExpense)
            }
            ForEach(Array(upcoming.enumerated()), id: \.offset) { _, commitment in
                upcomingRow(commitment, note: "Recurrente · por caer")
            }
            ForEach(Array(nextMonth.enumerated()), id: \.offset) { _, commitment in
                upcomingRow(commitment, note: "Recurrente · se paga en \(nextMonthName)")
            }
        }
    }

    /// "Netflix · por caer   $139": un recurrente que ese día todavía no se
    /// cobra. Apagado, porque aún no es un gasto.
    /// "noviembre": a dónde se va lo cobrado después del corte.
    private var nextMonthName: String {
        let next = model.calendar.date(byAdding: .month, value: 1, to: model.month) ?? model.month
        return LanaDateFormat.monthNameLowercased(next)
    }

    private func upcomingRow(_ commitment: Commitment, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
            VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                Text(commitment.concept)
                    .lanaFont(.rowTitle)
                    .foregroundStyle(lana.ink70)
                Text(note)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
            }
            Spacer(minLength: Space.sm.rawValue)
            Text(MoneyDisplay.full(Money(amount: abs(commitment.amount.amount), currency: commitment.amount.currency)))
                .lanaFont(.rowAmount)
                .foregroundStyle(lana.ink70)
        }
        .frame(minHeight: LanaMetrics.minRowHeight)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        let date = model.calendar.date(byAdding: .day, value: day - 1, to: model.month) ?? model.month
        let total = data.daily.first { $0.day == day }?.amount ?? 0
        return HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
            Text(LanaDateFormat.dayHeader(date, calendar: model.calendar))
                .lanaFont(.bodyEmphasis)
                .foregroundStyle(lana.ink)
            Spacer(minLength: Space.sm.rawValue)
            if total > 0 {
                Text(MoneyDisplay.whole(Money(amount: total, currency: data.currency)))
                    .lanaFont(.rowAmountStrong)
                    .foregroundStyle(lana.ink)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .lanaFont(.caption2)
                    .foregroundStyle(lana.ink50)
                    .frame(width: LanaMetrics.minTouchTarget, height: LanaMetrics.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dejar de ver este día")
        }
    }
}

import LanaCore
import LanaDesign
import SwiftUI

/// Filas de movimiento separadas por una línea fina, sin línea tras la última.
/// La misma forma en Hoy y en los días de Mes.
struct MovementRows: View {
    let expenses: [Expense]
    let model: DashboardModel
    let onSelect: (Expense) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                Button {
                    onSelect(expense)
                } label: {
                    row(for: expense)
                }
                .buttonStyle(.plain)
                if index < expenses.count - 1 {
                    HairlineDivider()
                }
            }
        }
    }

    /// Separada de `body`: con todos los argumentos inline, el type-checker
    /// tarda de más dentro del `ForEach`.
    private func row(for expense: Expense) -> MovementRow {
        let subtitle = model.subtitle(for: expense)
        // La parte que le toca a quien mira, no el monto completo del evento
        // (`Expense.personalAmount`, ADR-0029).
        let personal = expense.personalAmount(viewerIdentities: model.viewerIdentities)
        let totalText = expense.sharedListID != nil && personal != expense.amount
            ? "de \(MoneyDisplay.full(expense.amount))"
            : nil
        return MovementRow(
            title: expense.concept,
            subtitle: subtitle.text,
            amountText: MoneyDisplay.full(personal),
            secondaryAmountText: totalText,
            isIncome: expense.kind == .income,
            isSubtitleMuted: subtitle.isMuted,
            needsReview: expense.needsReview,
            isShared: expense.sharedListID != nil)
    }
}

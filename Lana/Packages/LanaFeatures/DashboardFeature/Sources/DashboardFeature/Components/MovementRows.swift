import LanaCore
import LanaDesign
import SwiftUI

/// Filas de movimiento separadas por una línea fina, sin línea tras la última.
/// La misma forma en Hoy y en los días de Mes.
struct MovementRows: View {
    @Environment(\.lana) private var lana
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
                        .background(highlight(for: expense))
                }
                .buttonStyle(.plain)
                if index < expenses.count - 1 {
                    HairlineDivider()
                }
            }
        }
    }

    /// El resalte de una fila recién guardada, que se disuelve solo: la
    /// consecuencia de haber dictado tiene que verse (rediseño, sección 08).
    private func highlight(for expense: Expense) -> some View {
        let isHighlighted = model.highlightedExpenseIDs.contains(expense.id)
        return RoundedRectangle(cornerRadius: Radius.inner.rawValue, style: .continuous)
            .fill(isHighlighted ? lana.accentHighlight : .clear)
            .padding(.horizontal, -Space.p10.rawValue)
            .animation(.easeOut(duration: 0.9), value: isHighlighted)
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

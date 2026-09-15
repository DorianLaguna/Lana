import LanaCore
import LanaDesign
import SwiftUI

/// "Lista agrupada por día, con ingresos y gastos" (Docs/PLAN.md → Fase 6).
public struct DaySectionListView: View {
    @Environment(\.lana) private var lana

    private let sections: [DaySection]
    private let onSelect: (Expense) -> Void
    private let viewerIdentities: [SharedListID: ParticipantID]

    public init(
        sections: [DaySection],
        onSelect: @escaping (Expense) -> Void = { _ in },
        viewerIdentities: [SharedListID: ParticipantID] = [:]) {
        self.sections = sections
        self.onSelect = onSelect
        self.viewerIdentities = viewerIdentities
    }

    public var body: some View {
        if sections.isEmpty {
            EmptyStateView(
                systemImage: "tray",
                title: "Sin movimientos este mes",
                message: "Cuando registres algo, aparece aquí.")
        } else {
            LazyVStack(alignment: .leading, spacing: Space.md.rawValue) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                        Text(section.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .lanaFont(.caption)
                            .foregroundStyle(lana.ink50)

                        LanaCard {
                            VStack(spacing: Space.xs.rawValue) {
                                ForEach(section.items) { expense in
                                    Button {
                                        onSelect(expense)
                                    } label: {
                                        row(for: expense)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Separada de `body` a propósito — con todos los argumentos de
    /// `TransactionRow` inline, el type-checker tardaba más de lo
    /// razonable dentro del `ForEach`/`Button` anidados (error real de
    /// `swift build`, no de Xcode con whole-module-optimization).
    private func row(for expense: Expense) -> some View {
        let categoryName = expense.category ?? "Ingreso"
        let categoryColor = lana.categoryRamp[(expense.category ?? "ingreso").stableRampIndex]
        // La parte que le toca a quien mira, no el monto completo del
        // evento — un gasto compartido no se ve como si lo hubiera
        // absorbido todo (`Expense.personalAmount`, LanaCore).
        let personalAmount = expense.personalAmount(viewerIdentities: viewerIdentities)
        let amountText = personalAmount.formatted()
        // Con solo la parte de quien mira, la fila se lee como si el gasto
        // hubiera sido de ese monto (ADR-0029) — "de $800" dice de cuánto
        // era en realidad. Solo cuando difieren: si te tocó el total (lo
        // pagaste tú y nadie más debe), repetirlo sería ruido.
        let totalText = expense.sharedListID != nil && personalAmount != expense.amount
            ? "de \(expense.amount.formatted())"
            : nil
        return TransactionRow(
            concept: expense.concept,
            categoryName: categoryName,
            categoryColor: categoryColor,
            amountText: amountText,
            secondaryAmountText: totalText,
            isIncome: expense.kind == .income,
            needsReview: expense.needsReview,
            isShared: expense.sharedListID != nil)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                DaySectionListView(sections: [
                    DaySection(day: Date(), items: [
                        Expense(
                            kind: .expense,
                            amount: Money(amount: 131, currency: .mxn),
                            concept: "Dulces",
                            category: "despensa",
                            date: Date()),
                        Expense(
                            kind: .income,
                            amount: Money(amount: 5000, currency: .mxn),
                            concept: "Nómina",
                            date: Date())
                    ])
                ])
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

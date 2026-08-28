import LanaCore
import LanaDesign
import SwiftUI

/// "Lista agrupada por día, con ingresos y gastos" (Docs/PLAN.md → Fase 6).
public struct DaySectionListView: View {
    @Environment(\.lana) private var lana

    private let sections: [DaySection]
    private let onSelect: (Expense) -> Void

    public init(sections: [DaySection], onSelect: @escaping (Expense) -> Void = { _ in }) {
        self.sections = sections
        self.onSelect = onSelect
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
                            .foregroundStyle(lana.textSecondary)

                        LanaCard {
                            VStack(spacing: Space.xs.rawValue) {
                                ForEach(section.items) { expense in
                                    Button {
                                        onSelect(expense)
                                    } label: {
                                        TransactionRow(
                                            concept: expense.concept,
                                            categoryName: expense.category ?? "Ingreso",
                                            categoryColor: lana
                                                .categoryRamp[(expense.category ?? "ingreso").stableRampIndex],
                                            amountText: expense.amount.formatted(),
                                            isIncome: expense.kind == .income,
                                            needsReview: expense.needsReview)
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

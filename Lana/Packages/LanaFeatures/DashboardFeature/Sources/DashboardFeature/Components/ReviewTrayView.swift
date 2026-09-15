import LanaCore
import LanaDesign
import SwiftUI

/// "Bandeja de needsReview" (Docs/PLAN.md → Fase 6): lo que se capturó
/// ambiguo y sigue esperando confirmación. Un dato con acción al lado, no
/// una advertencia (Docs/.claude/skills/theming → Tono).
public struct ReviewTrayView: View {
    @Environment(\.lana) private var lana
    @State private var isExpanded = false

    private let sections: [DaySection]
    private let onSelect: (Expense) -> Void

    public init(sections: [DaySection], onSelect: @escaping (Expense) -> Void = { _ in }) {
        self.sections = sections
        self.onSelect = onSelect
    }

    public var body: some View {
        if !sections.isEmpty {
            LanaCard {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(spacing: Space.xs.rawValue) {
                        ForEach(sections.flatMap(\.items)) { expense in
                            Button {
                                onSelect(expense)
                            } label: {
                                TransactionRow(
                                    concept: expense.concept,
                                    categoryName: expense.category ?? "Ingreso",
                                    categoryColor: lana.attention,
                                    amountText: expense.amount.formatted(),
                                    isIncome: expense.kind == .income,
                                    needsReview: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, Space.sm.rawValue)
                } label: {
                    Label("\(sections.flatMap(\.items).count) por revisar", systemImage: "exclamationmark.circle")
                        .foregroundStyle(lana.attention)
                        .lanaFont(.headline)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                ReviewTrayView(sections: [
                    DaySection(day: Date(), items: [
                        Expense(
                            kind: .expense,
                            amount: Money(amount: 45000, currency: .mxn),
                            concept: "Estacionamiento",
                            category: "transporte",
                            date: Date(),
                            needsReview: true)
                    ])
                ])
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

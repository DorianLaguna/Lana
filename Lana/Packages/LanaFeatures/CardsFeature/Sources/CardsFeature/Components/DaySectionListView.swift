import LanaCore
import LanaDesign
import SwiftUI

/// Los movimientos de una tarjeta, agrupados por día (rediseño, sección 05).
/// Copia local de la misma idea en `DashboardFeature`: las features no se
/// importan entre sí y `LanaDesign` no conoce el dominio.
struct DaySectionListView: View {
    @Environment(\.lana) private var lana

    private let sections: [DaySection]
    private let cardAlias: String
    private let onSelect: (Expense) -> Void

    init(sections: [DaySection], cardAlias: String, onSelect: @escaping (Expense) -> Void = { _ in }) {
        self.sections = sections
        self.cardAlias = cardAlias
        self.onSelect = onSelect
    }

    var body: some View {
        if sections.isEmpty {
            EmptyStateView(
                systemImage: "tray",
                title: "Sin movimientos",
                message: "Cuando pagues algo con esta tarjeta, aparece aquí.")
        } else {
            LazyVStack(alignment: .leading, spacing: Space.p20.rawValue) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(LanaDateFormat.dayHeader(section.day), style: .minor)
                        rows(for: section)
                    }
                }
            }
        }
    }

    private func rows(for section: DaySection) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, expense in
                Button {
                    onSelect(expense)
                } label: {
                    row(for: expense)
                }
                .buttonStyle(.plain)
                if index < section.items.count - 1 {
                    HairlineDivider()
                }
            }
        }
    }

    private func row(for expense: Expense) -> MovementRow {
        MovementRow(
            title: expense.concept,
            subtitle: subtitle(for: expense),
            amountText: expense.amount.formatted(),
            isIncome: expense.kind == .income,
            needsReview: expense.needsReview,
            isShared: expense.sharedListID != nil)
    }

    /// Aquí la tarjeta se da por sabida —es su pantalla—, así que el subtítulo
    /// dice la categoría y, para un ingreso, de dónde vino.
    private func subtitle(for expense: Expense) -> String {
        guard expense.kind == .expense else { return "Ingreso · \(cardAlias)" }
        guard let category = expense.category, !category.isEmpty else { return "Sin categoría" }
        return SuggestedCategory(rawValue: category)?.displayName ?? category.prefix(1).uppercased() + category
            .dropFirst()
    }
}

#Preview {
    if let card = try? Card(
        alias: "Bancomer", lastFourDigits: "9131",
        limit: Money(amount: 17000, currency: .mxn), cutoffDay: 12, dueDay: 20) {
        ScrollView {
            VStack(spacing: Space.md.rawValue) {
                ForEach(LanaTheme.allCases) { theme in
                    DaySectionListView(
                        sections: [
                            DaySection(day: Date(), items: [
                                Expense(
                                    kind: .expense,
                                    amount: Money(amount: 620, currency: .mxn),
                                    concept: "Súper semanal",
                                    category: "despensa",
                                    date: Date(),
                                    paymentMethod: .credit(cardID: card.id))
                            ])
                        ],
                        cardAlias: card.alias)
                        .padding(.horizontal, LanaMetrics.screenMargin)
                        .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                        .lanaTheme(theme)
                }
            }
        }
    }
}

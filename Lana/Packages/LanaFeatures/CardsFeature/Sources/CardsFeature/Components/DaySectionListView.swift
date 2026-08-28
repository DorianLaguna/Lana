import LanaCore
import LanaDesign
import SwiftUI

/// Lista de transacciones agrupada por día. Copia local de la misma vista
/// en `DashboardFeature` — `LanaDesign` no depende de `LanaCore` (decisión
/// de Fase 0), así que no se puede promover ahí, y las features no se
/// importan entre sí (Docs/ARCHITECTURE.md). Si aparece un tercer lugar que
/// la necesite, vale la pena repensar esa regla; con dos, duplicar esto es
/// más simple que romperla.
struct DaySectionListView: View {
    @Environment(\.lana) private var lana

    private let sections: [DaySection]
    private let onSelect: (Expense) -> Void

    init(sections: [DaySection], onSelect: @escaping (Expense) -> Void = { _ in }) {
        self.sections = sections
        self.onSelect = onSelect
    }

    var body: some View {
        if sections.isEmpty {
            EmptyStateView(
                systemImage: "tray",
                title: "Sin movimientos",
                message: "Cuando registres algo con esta tarjeta, aparece aquí.")
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
                                            categoryColor: lana.categoryRamp[(expense.category ?? "ingreso")
                                                .stableRampIndex],
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

extension String {
    /// Si es una de las categorías cerradas, su índice ya es único por
    /// construcción (`SuggestedCategory.rampIndex`) — sin choques posibles
    /// entre categorías reales. Si no, cae a un hash estable (djb2) como
    /// respaldo — el `Hashable` de Swift cambia de semilla en cada corrida
    /// del proceso y no sirve para esto. El módulo (12) tiene que
    /// coincidir con `LanaColors.categoryRamp.count`.
    var stableRampIndex: Int {
        if let known = SuggestedCategory(rawValue: self) {
            return known.rampIndex
        }
        var hash = 5381
        for scalar in unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash) % 12
    }
}

#Preview {
    if let card = try? Card(
        alias: "BBVA Oro", lastFourDigits: "4821",
        limit: Money(amount: 10000, currency: .mxn), cutoffDay: 15, dueDay: 5) {
        ScrollView {
            VStack(spacing: Space.md.rawValue) {
                ForEach(LanaTheme.allCases) { theme in
                    DaySectionListView(sections: [
                        DaySection(day: Date(), items: [
                            Expense(
                                kind: .expense,
                                amount: Money(amount: 620, currency: .mxn),
                                concept: "Súper semanal",
                                category: "despensa",
                                date: Date(),
                                paymentMethod: .credit(cardID: card.id))
                        ])
                    ])
                    .lanaTheme(theme)
                }
            }
            .padding(Space.md.rawValue)
        }
    }
}

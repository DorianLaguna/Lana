import LanaCore
import LanaDesign
import SwiftUI

/// El drill-down de una categoría (Fase 6.5, calca `CategoriaDetalle.dc.html`).
/// Llega por navegación desde `CategoryBreakdownChart` — el botón de
/// regresar lo da `NavigationStack`, no se dibuja a mano.
public struct CategoryDetailView: View {
    @Environment(\.lana) private var lana
    private let model: CategoryDetailModel
    private let onExpenseTap: (Expense) -> Void

    public init(model: CategoryDetailModel, onExpenseTap: @escaping (Expense) -> Void) {
        self.model = model
        self.onExpenseTap = onExpenseTap
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DrillDownTotal(
                    label: model.totalLabel,
                    amount: Money(amount: model.total, currency: model.currency),
                    summary: model.summary,
                    share: model.periodShare)
                    .padding(.bottom, Space.p30.rawValue)

                if !model.subcategoryTotals.isEmpty {
                    SectionHeader("Subcategorías")
                        .padding(.bottom, Space.md.rawValue)
                    RankedBarList(items: model.subcategoryTotals.map(rankedItem), restFill: .muted)
                        .padding(.bottom, Space.p30.rawValue)
                }

                DaySectionListView(
                    sections: model.daySections,
                    source: model.source,
                    onSelect: onExpenseTap)
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle(model.category.capitalized)
        .lanaInlineNavigationTitle()
    }

    private func rankedItem(_ total: SubcategoryTotal) -> RankedBarList.Item {
        RankedBarList.Item(
            id: total.subcategory,
            title: total.subcategory.capitalized,
            amountText: Money(amount: total.amount, currency: total.currency).formatted(),
            value: NSDecimalNumber(decimal: total.amount).doubleValue)
    }
}

#Preview {
    let dashboard = DashboardModel(
        store: InMemoryExpenseStore(seed: [
            Expense(
                kind: .expense,
                amount: Money(amount: 620, currency: .mxn),
                concept: "Súper semanal",
                category: "despensa",
                subcategory: "abarrotes",
                date: Date())
        ]),
        vocabularyStore: InMemoryCorrectionVocabularyStore(),
        cardStore: InMemoryCardStore(),
        sharedListStore: InMemorySharedListStore())
    return NavigationStack {
        CategoryDetailView(
            model: CategoryDetailModel(category: "despensa", source: dashboard),
            onExpenseTap: { _ in })
    }
    .task { await dashboard.onAppear() }
}

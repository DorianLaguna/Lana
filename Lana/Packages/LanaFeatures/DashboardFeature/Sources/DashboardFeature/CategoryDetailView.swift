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
            VStack(spacing: Space.md.rawValue) {
                LanaCard {
                    VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                        Text("Total en el mes")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.ink50)
                        Text(Money(amount: model.total, currency: model.currency).formatted())
                            .lanaFont(.largeAmount)
                            .monospacedDigit()
                            .foregroundStyle(lana.ink)
                        Text("\(model.expenses.count) " + (model.expenses.count == 1 ? "gasto" : "gastos"))
                            .lanaFont(.caption)
                            .foregroundStyle(lana.ink50)
                    }
                }

                if !model.subcategoryTotals.isEmpty {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Subcategorías")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.ink50)
                            ForEach(model.subcategoryTotals) { total in
                                HStack {
                                    Text(total.subcategory.capitalized)
                                        .lanaFont(.body)
                                        .foregroundStyle(lana.ink)
                                    Spacer()
                                    Text(Money(amount: total.amount, currency: total.currency).formatted())
                                        .lanaFont(.body)
                                        .monospacedDigit()
                                        .foregroundStyle(lana.ink)
                                }
                            }
                        }
                    }
                }

                DaySectionListView(
                    sections: model.daySections,
                    onSelect: onExpenseTap,
                    viewerIdentities: model.viewerIdentities)
            }
            .padding(Space.md.rawValue)
        }
        .background(lana.bg)
        .navigationTitle(model.category.capitalized)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
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

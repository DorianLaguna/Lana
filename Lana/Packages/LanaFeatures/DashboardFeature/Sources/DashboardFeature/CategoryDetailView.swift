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
                            .foregroundStyle(lana.textSecondary)
                        Text(Money(amount: model.total, currency: model.currency).formatted())
                            .lanaFont(.largeAmount)
                            .monospacedDigit()
                            .foregroundStyle(lana.textPrimary)
                        Text("\(model.expenses.count) " + (model.expenses.count == 1 ? "gasto" : "gastos"))
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    }
                }

                if !model.subcategoryTotals.isEmpty {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Subcategorías")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.textSecondary)
                            ForEach(model.subcategoryTotals) { total in
                                HStack {
                                    Text(total.subcategory.capitalized)
                                        .lanaFont(.body)
                                        .foregroundStyle(lana.textPrimary)
                                    Spacer()
                                    Text(Money(amount: total.amount, currency: total.currency).formatted())
                                        .lanaFont(.body)
                                        .monospacedDigit()
                                        .foregroundStyle(lana.textPrimary)
                                }
                            }
                        }
                    }
                }

                DaySectionListView(sections: model.daySections, onSelect: onExpenseTap)
            }
            .padding(Space.md.rawValue)
        }
        .background(lana.surface)
        .navigationTitle(model.category.capitalized)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.onAppear() }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(model: CategoryDetailModel(
            category: "despensa",
            store: InMemoryExpenseStore(seed: [
                Expense(
                    kind: .expense,
                    amount: Money(amount: 620, currency: .mxn),
                    concept: "Súper semanal",
                    category: "despensa",
                    subcategory: "abarrotes",
                    date: Date())
            ]),
            month: Date()), onExpenseTap: { _ in })
    }
}

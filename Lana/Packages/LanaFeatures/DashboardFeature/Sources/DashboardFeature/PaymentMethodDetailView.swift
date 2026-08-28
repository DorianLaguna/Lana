import LanaCore
import LanaDesign
import SwiftUI

/// El drill-down de una forma de pago (mismo patrón que `CategoryDetailView`).
/// Llega por navegación desde "Por forma de pago" en el Dashboard — el
/// botón de regresar lo da `NavigationStack`, no se dibuja a mano.
public struct PaymentMethodDetailView: View {
    @Environment(\.lana) private var lana
    private let model: PaymentMethodDetailModel
    private let onExpenseTap: (Expense) -> Void

    public init(model: PaymentMethodDetailModel, onExpenseTap: @escaping (Expense) -> Void) {
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

                // Solo crédito/débito traen tarjeta — efectivo y
                // transferencia dejan `cardTotals` vacío y esta tarjeta ni
                // aparece (pedido explícito del usuario: saber con cuál
                // tarjeta se pagó cada cosa).
                if !model.cardTotals.isEmpty {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Por tarjeta")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.textSecondary)
                            ForEach(model.cardTotals) { total in
                                HStack {
                                    Text(total.alias)
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

                if !model.categoryTotals.isEmpty {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Por categoría")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.textSecondary)
                            ForEach(model.categoryTotals) { total in
                                HStack {
                                    Text(total.category.capitalized)
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
        .navigationTitle(model.label.capitalized)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.onAppear() }
    }
}

#Preview {
    if let card = try? Card(alias: "BBVA Oro", lastFourDigits: "4821", limit: nil, cutoffDay: nil, dueDay: nil) {
        NavigationStack {
            PaymentMethodDetailView(
                model: PaymentMethodDetailModel(
                    label: "crédito",
                    store: InMemoryExpenseStore(seed: [
                        Expense(
                            kind: .expense,
                            amount: Money(amount: 620, currency: .mxn),
                            concept: "Súper semanal",
                            category: "despensa",
                            date: Date(),
                            paymentMethod: .credit(cardID: card.id))
                    ]),
                    cardStore: InMemoryCardStore(seed: [card]),
                    month: Date()),
                onExpenseTap: { _ in })
        }
    }
}

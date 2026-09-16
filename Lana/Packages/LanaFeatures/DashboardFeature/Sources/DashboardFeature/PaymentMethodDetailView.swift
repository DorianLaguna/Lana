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
            VStack(alignment: .leading, spacing: 0) {
                DrillDownTotal(
                    label: model.totalLabel,
                    amount: Money(amount: model.total, currency: model.currency),
                    summary: model.summary,
                    share: model.periodShare)
                    .padding(.bottom, Space.p30.rawValue)

                // Solo crédito/débito traen tarjeta — efectivo y
                // transferencia dejan `cardTotals` vacío y esta sección ni
                // aparece (pedido explícito del usuario: saber con cuál
                // tarjeta se pagó cada cosa).
                if !model.cardTotals.isEmpty {
                    SectionHeader("Por tarjeta")
                        .padding(.bottom, Space.xs.rawValue)
                    cardList
                        .padding(.bottom, Space.p30.rawValue)
                }

                if !model.categoryTotals.isEmpty {
                    SectionHeader("Por categoría")
                        .padding(.bottom, Space.md.rawValue)
                    RankedBarList(items: model.categoryTotals.map(rankedItem), restFill: .muted)
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
        .navigationTitle(model.label.capitalized)
        .lanaInlineNavigationTitle()
        .task { await model.onAppear() }
    }

    /// Una fila por tarjeta, con el color que el usuario le puso — el mismo
    /// rectángulo que en Tarjetas, para reconocerla sin leer el alias.
    private var cardList: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.cardTotals.enumerated()), id: \.element.id) { index, total in
                HStack(spacing: Space.p12.rawValue) {
                    RoundedRectangle(cornerRadius: Radius.swatch.rawValue, style: .continuous)
                        .fill(total.colorHex.flatMap { Color(hex: $0) } ?? lana.surface3)
                        .frame(width: LanaMetrics.cardSwatchWidth, height: LanaMetrics.cardSwatchHeight)
                        .accessibilityHidden(true)
                    Text(total.alias)
                        .lanaFont(.rowTitle)
                        .foregroundStyle(total.colorHex == nil ? lana.ink70 : lana.ink)
                    Spacer(minLength: Space.sm.rawValue)
                    Text(Money(amount: total.amount, currency: total.currency).formatted())
                        .lanaFont(.rowAmount)
                        .foregroundStyle(lana.ink)
                }
                .frame(minHeight: LanaMetrics.minRowHeight)
                .accessibilityElement(children: .combine)
                if index < model.cardTotals.count - 1 {
                    HairlineDivider(strong: true)
                }
            }
        }
    }

    private func rankedItem(_ total: CategoryWithinPaymentMethodTotal) -> RankedBarList.Item {
        RankedBarList.Item(
            id: total.category,
            title: SuggestedCategory(rawValue: total.category)?.displayName
                ?? total.category.prefix(1).uppercased() + total.category.dropFirst(),
            amountText: Money(amount: total.amount, currency: total.currency).formatted(),
            value: NSDecimalNumber(decimal: total.amount).doubleValue)
    }
}

#Preview {
    if let card = try? Card(alias: "BBVA Oro", lastFourDigits: "4821", limit: nil, cutoffDay: nil, dueDay: nil) {
        let cardStore = InMemoryCardStore(seed: [card])
        let dashboard = DashboardModel(
            store: InMemoryExpenseStore(seed: [
                Expense(
                    kind: .expense,
                    amount: Money(amount: 620, currency: .mxn),
                    concept: "Súper semanal",
                    category: "despensa",
                    date: Date(),
                    paymentMethod: .credit(cardID: card.id))
            ]),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: cardStore,
            sharedListStore: InMemorySharedListStore())
        NavigationStack {
            PaymentMethodDetailView(
                model: PaymentMethodDetailModel(label: "crédito", source: dashboard, cardStore: cardStore),
                onExpenseTap: { _ in })
        }
        .task { await dashboard.onAppear() }
    }
}

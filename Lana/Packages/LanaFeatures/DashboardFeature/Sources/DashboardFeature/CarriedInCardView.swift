import LanaCore
import LanaDesign
import SwiftUI

/// Lo que se compró con una tarjeta después del corte del mes anterior y ya
/// cuenta en este (ADR-0060). Se llega tocando la tarjeta en "Ya cuentan en
/// octubre", en Hoy. Deriva de `DashboardModel` en vivo: editar o borrar una
/// compra desde aquí se refleja sin recargar.
struct CarriedInCardView: View {
    @Environment(\.lana) private var lana
    let model: DashboardModel
    let cardID: CardID
    let currency: Currency
    let onExpenseTap: (Expense) -> Void

    var body: some View {
        let item = model.carriedInByCard().first { $0.card.id == cardID && $0.amount.currency == currency }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let item {
                    DrillDownTotal(
                        label: "Cuenta en \(LanaDateFormat.monthNameLowercased(model.month))",
                        amount: item.amount,
                        summary: summary(item),
                        share: model.spentShare(of: item.amount))
                        .padding(.bottom, Space.p30.rawValue)
                }
                let purchases = model.carriedInSections(for: cardID, in: currency, recurring: false)
                let recurring = model.carriedInSections(for: cardID, in: currency, recurring: true)
                if !purchases.isEmpty || recurring.isEmpty {
                    group("Compras", amount: item?.purchasesAmount, sections: purchases)
                }
                if !recurring.isEmpty {
                    group("Recurrentes", amount: item?.recurringAmount, sections: recurring)
                }
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle(item?.card.alias ?? "Tarjeta")
        .lanaInlineNavigationTitle()
    }

    /// Un grupo con su total a la derecha del encabezado y sus movimientos
    /// por día.
    private func group(_ title: String, amount: Decimal?, sections: [DaySection]) -> some View {
        VStack(alignment: .leading, spacing: Space.p12.rawValue) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title)
                Spacer(minLength: Space.sm.rawValue)
                if let amount {
                    Text(MoneyDisplay.full(Money(amount: amount, currency: currency)))
                        .lanaFont(.detail)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink70)
                }
            }
            DaySectionListView(sections: sections, source: model, onSelect: onExpenseTap)
        }
        .padding(.bottom, Space.p30.rawValue)
    }

    /// "4 compras, 2 recurrentes después del corte del 23 · 40% de tu mes".
    private func summary(_ item: CarriedInCard) -> String {
        var parts = [CarriedInCardsCard.countText(item)]
        if let cutoffDay = item.card.cutoffDay {
            parts[0] += " después del corte del \(cutoffDay)"
        }
        parts.append("\(Int((model.spentShare(of: item.amount) * 100).rounded()))% de tu mes")
        return parts.joined(separator: " · ")
    }
}

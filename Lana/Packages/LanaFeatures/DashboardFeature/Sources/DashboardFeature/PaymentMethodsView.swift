import LanaCore
import LanaDesign
import SwiftUI

/// Con qué se pagó el mes, de mayor a menor. Se entra desde la fila "Formas de
/// pago" de Mes; cada forma de pago abre su detalle.
struct PaymentMethodsView: View {
    @Environment(\.lana) private var lana
    let model: DashboardModel
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.p28.rawValue) {
                if let total = model.monthTotals.first {
                    VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                        Text("Gastado en \(LanaDateFormat.monthNameLowercased(model.month))")
                            .lanaFont(.footnote)
                            .foregroundStyle(lana.ink50)
                        Text(MoneyDisplay.full(Money(amount: total.expenses, currency: total.currency)))
                            .lanaFont(.screenAmount)
                            .foregroundStyle(lana.ink)
                    }
                }

                RankedBarList(items: model.primaryPaymentMethodTotals.map { total in
                    RankedBarList.Item(
                        id: total.category,
                        title: total.category.prefix(1).uppercased() + total.category.dropFirst(),
                        amountText: MoneyDisplay.whole(Money(amount: total.amount, currency: total.currency)),
                        value: NSDecimalNumber(decimal: total.amount).doubleValue)
                }) { item in
                    onSelect(item.id)
                }
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle("Formas de pago")
        .lanaInlineNavigationTitle()
    }
}

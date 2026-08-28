import LanaCore
import LanaDesign
import SwiftUI

/// Cuánto toca pagar de tarjetas en la quincena vigente — pedido explícito
/// del usuario. Sin lógica propia, refleja `UpcomingCardPaymentsModel`.
/// No aparece si no hay nada pendiente esta quincena — no tiene caso una
/// tarjeta vacía diciendo "no debes nada" junto a las demás.
public struct UpcomingCardPaymentsSection: View {
    @Environment(\.lana) private var lana
    private let dueThisPayPeriod: [UpcomingCardPaymentsModel.CardDue]
    private let totalsByCurrency: [UpcomingCardPaymentsModel.CurrencyTotal]

    public init(
        dueThisPayPeriod: [UpcomingCardPaymentsModel.CardDue],
        totalsByCurrency: [UpcomingCardPaymentsModel.CurrencyTotal]) {
        self.dueThisPayPeriod = dueThisPayPeriod
        self.totalsByCurrency = totalsByCurrency
    }

    public var body: some View {
        if !dueThisPayPeriod.isEmpty {
            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    Text("Tarjetas esta quincena")
                        .lanaFont(.caption)
                        .foregroundStyle(lana.textSecondary)

                    VStack(spacing: 0) {
                        ForEach(dueThisPayPeriod) { due in
                            HStack(spacing: Space.sm.rawValue) {
                                Text(due.card.alias)
                                    .lanaFont(.body)
                                    .foregroundStyle(lana.textPrimary)
                                Spacer()
                                Text(due.amount.formatted())
                                    .lanaFont(.body)
                                    .monospacedDigit()
                                    .foregroundStyle(lana.textPrimary)
                            }
                            .padding(.vertical, Space.xs.rawValue)
                            if due.id != dueThisPayPeriod.last?.id {
                                Divider()
                            }
                        }
                    }

                    if totalsByCurrency.count > 1 || dueThisPayPeriod.count > 1 {
                        Divider()
                        ForEach(totalsByCurrency) { total in
                            HStack {
                                Text("Total")
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.textSecondary)
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
        }
    }
}

#Preview {
    if let card = try? Card(
        alias: "BBVA Oro",
        lastFourDigits: "4821",
        limit: Money(amount: 10000, currency: .mxn),
        cutoffDay: 20,
        dueDay: 5) {
        ScrollView {
            VStack(spacing: Space.md.rawValue) {
                ForEach(LanaTheme.allCases) { theme in
                    UpcomingCardPaymentsSection(
                        dueThisPayPeriod: [
                            UpcomingCardPaymentsModel.CardDue(card: card, amount: Money(amount: 2450, currency: .mxn))
                        ],
                        totalsByCurrency: [
                            UpcomingCardPaymentsModel.CurrencyTotal(currency: .mxn, amount: 2450)
                        ])
                        .lanaTheme(theme)
                }
            }
            .padding(Space.md.rawValue)
        }
    }
}

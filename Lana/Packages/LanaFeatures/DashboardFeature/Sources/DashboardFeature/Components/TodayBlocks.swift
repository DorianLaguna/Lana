import LanaCore
import LanaDesign
import SwiftUI

/// "Te queda": la cifra más grande de la app, la barra de gasto sobre ingreso
/// y su pie (Hoy, sección 2).
struct TodayHero: View {
    @Environment(\.lana) private var lana
    let total: PeriodTotal
    /// Con más de una moneda, la etiqueta la nombra.
    let showsCurrency: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .lanaFont(.footnote)
                .foregroundStyle(lana.ink50)
                .padding(.bottom, Space.p6.rawValue)

            figure(Money(amount: total.income > 0 ? total.remaining : total.expenses, currency: total.currency))

            if let fraction = DashboardModel.spentFraction(of: total) {
                ProgressTrack(fraction: fraction, height: LanaMetrics.barMedium)
                    .padding(.top, Space.p12.rawValue)
                    .padding(.bottom, Space.p10.rawValue)
                HStack {
                    Text("Gastaste \(spent) de \(income)")
                    Spacer(minLength: Space.sm.rawValue)
                    Text("\(DashboardModel.percent(total.expenses, of: total.income))%")
                        .monospacedDigit()
                }
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
            } else {
                Text("Registra un ingreso para ver cuánto te queda.")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink42)
                    .padding(.top, Space.p10.rawValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        let base = total.income > 0 ? "Te queda" : "Gastaste"
        return showsCurrency ? "\(base) · \(total.currency.rawValue)" : base
    }

    private var spent: String {
        MoneyDisplay.compact(Money(amount: total.expenses, currency: total.currency))
    }

    private var income: String {
        MoneyDisplay.compact(Money(amount: total.income, currency: total.currency))
    }

    private func figure(_ money: Money) -> some View {
        let parts = MoneyDisplay.heroParts(money)
        return HStack(alignment: .firstTextBaseline, spacing: Space.xs.rawValue) {
            Text(parts.symbol)
                .lanaFont(.heroFraction)
                .foregroundStyle(lana.ink50)
            Text(parts.integer)
                .lanaFont(.heroAmount)
                .foregroundStyle(lana.ink)
                .contentTransition(.numericText())
            Text(parts.fraction)
                .lanaFont(.heroFraction)
                .foregroundStyle(lana.ink45)
                .contentTransition(.numericText())
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .animation(.easeOut(duration: 0.6), value: money)
    }
}

/// "Te toca $170 al día para llegar al 30 sin pasarte." (Hoy, sección 3).
struct DailyPaceCard: View {
    @Environment(\.lana) private var lana
    let pace: DailyPace

    var body: some View {
        LanaCard(padding: nil, radius: .inner, fill: isOverspent ? .attention : .surface) {
            message
                .lanaFont(.callout)
                .foregroundStyle(lana.ink70)
                .padding(.vertical, Space.p14.rawValue)
                .padding(.horizontal, Space.md.rawValue)
        }
    }

    private var isOverspent: Bool {
        switch pace {
        case .overspent, .committed: true
        case .allowance: false
        }
    }

    private var message: Text {
        switch pace {
        case let .allowance(money, untilDay):
            Text("Te toca \(emphasized(MoneyDisplay.whole(money))) al día para llegar al \(untilDay) sin pasarte.")
        case let .overspent(money):
            Text("Ya te pasaste por \(emphasized(MoneyDisplay.compact(money))) este mes.")
        case let .committed(short):
            // Todavía no se gasta de más: falta para cubrir lo que viene. Se
            // dice como dato, con la cifra, sin reproche (ADR-0046).
            Text("Lo que queda ya tiene dueño: faltan \(emphasized(MoneyDisplay.compact(short))) para lo que viene.")
        }
    }

    private func emphasized(_ text: String) -> Text {
        Text(text)
            .foregroundStyle(lana.ink)
            .fontWeight(.semibold)
    }
}

/// La fila "Por revisar" — solo existe si hay algo que revisar (Hoy, sección 4).
struct ReviewPromptRow: View {
    @Environment(\.lana) private var lana
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.p12.rawValue) {
                Text("\(count)")
                    .lanaFont(.footnote)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(lana.bg)
                    .frame(width: LanaMetrics.badge, height: LanaMetrics.badge)
                    .background(lana.attention, in: Circle())
                Text("Por revisar")
                    .lanaFont(.bodyEmphasis)
                    .foregroundStyle(lana.ink)
                Spacer(minLength: Space.sm.rawValue)
                RowChevron()
            }
            .padding(.vertical, Space.p15.rawValue)
            .padding(.horizontal, Space.md.rawValue)
            .background(
                lana.attentionSoft,
                in: RoundedRectangle(cornerRadius: Radius.inner.rawValue, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) por revisar")
    }
}

/// "A pagar de tarjetas" en la quincena en curso (Hoy, sección 5).
struct FortnightCardsCard: View {
    @Environment(\.lana) private var lana
    let dues: [UpcomingCardPaymentsModel.CardDue]
    let totals: [UpcomingCardPaymentsModel.CurrencyTotal]

    var body: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.p10.rawValue) {
                HStack(alignment: .firstTextBaseline) {
                    Text("A pagar de tarjetas")
                        .lanaFont(.bodyEmphasis)
                        .fontWeight(.regular)
                        .foregroundStyle(lana.ink70)
                    Spacer(minLength: Space.sm.rawValue)
                    Text(totalText)
                        .lanaFont(.cardAmount)
                        .foregroundStyle(lana.ink)
                }
                .padding(.bottom, Space.xs.rawValue)

                ForEach(dues) { due in
                    HStack(spacing: Space.p10.rawValue) {
                        RoundedRectangle(cornerRadius: Radius.hairline.rawValue, style: .continuous)
                            .fill(Color(hex: due.card.colorHex) ?? lana.accentFill)
                            .frame(width: LanaMetrics.cardTickWidth, height: LanaMetrics.cardTickHeight)
                        Text(dueLabel(due))
                            .lanaFont(.detail)
                            .foregroundStyle(lana.ink70)
                            .lineLimit(1)
                        Spacer(minLength: Space.sm.rawValue)
                        Text(MoneyDisplay.full(due.amount))
                            .lanaFont(.detail)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(lana.ink)
                    }
                }
            }
        }
    }

    private var totalText: String {
        totals
            .map { MoneyDisplay.full(Money(amount: $0.amount, currency: $0.currency)) }
            .joined(separator: " · ")
    }

    private func dueLabel(_ due: UpcomingCardPaymentsModel.CardDue) -> String {
        guard let dueDay = due.card.dueDay else { return due.card.alias }
        return "\(due.card.alias) · límite día \(dueDay)"
    }
}

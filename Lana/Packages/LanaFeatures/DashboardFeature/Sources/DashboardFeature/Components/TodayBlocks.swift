import LanaCore
import LanaDesign
import SwiftUI

/// "Te queda": la cifra más grande de la app, la barra de gasto sobre ingreso
/// y su pie (Hoy, sección 2). Al cerrar el mes dice cuánto se ahorró
/// (ADR-0060).
struct TodayHero: View {
    @Environment(\.lana) private var lana
    let total: PeriodTotal
    /// Con más de una moneda, la etiqueta la nombra.
    let showsCurrency: Bool
    /// El último día del mes, o un mes que ya pasó.
    var isClosing = false
    /// "Incluye $24,000 que esperas el 14 y el 30." — los sueldos que la
    /// cifra ya cuenta y todavía no caen.
    var expectedNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .lanaFont(.footnote)
                .foregroundStyle(lana.ink50)
                .padding(.bottom, Space.p6.rawValue)

            figure(Money(amount: figureAmount, currency: total.currency))

            if let fraction = DashboardModel.spentFraction(of: total) {
                ProgressTrack(fraction: fraction, height: LanaMetrics.barMedium)
                    .padding(.top, Space.p12.rawValue)
                    .padding(.bottom, Space.p10.rawValue)
                HStack {
                    Text("Gastaste \(spent) de \(income)")
                    Spacer(minLength: Space.sm.rawValue)
                    Text("\(Percentage.rounded(total.expenses, of: total.income))%")
                        .monospacedDigit()
                }
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
                if let expectedNote, !isClosing {
                    Text(expectedNote)
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                        .padding(.top, Space.p6.rawValue)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        let base = switch (total.income > 0, isClosing) {
        case (false, _): "Gastaste"
        case (true, false): "Te queda"
        // Se dice como dato, sin reproche (Docs/CLAUDE.md → Tono).
        case (true, true): total.remaining >= 0 ? "Ahorraste" : "Gastaste de más"
        }
        return showsCurrency ? "\(base) · \(total.currency.rawValue)" : base
    }

    /// Al cerrar, "Gastaste de más" ya dice el signo: la cifra va sin él.
    private var figureAmount: Decimal {
        guard total.income > 0 else { return total.expenses }
        return isClosing ? abs(total.remaining) : total.remaining
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
    /// Cuántos de esos llegaron por Apple Pay. En cero no se dice nada: lo
    /// demás lo dictó el usuario.
    let applePayCount: Int
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
                // `ink60`, no el `ink50` del handoff: sobre `attentionSoft`
                // no llega a 4.5:1 en claro.
                if applePayCount > 0 {
                    Text(applePayText)
                        .lanaFont(.footnote)
                        .foregroundStyle(lana.ink60)
                }
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
        .accessibilityLabel(applePayCount > 0 ? "\(count) por revisar, \(applePayText)" : "\(count) por revisar")
    }

    private var applePayText: String {
        "\(applePayCount) de Apple Pay"
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

/// "Ya cuentan en octubre": lo comprado con tarjeta el mes anterior, después
/// del corte, que ya cuenta en este (ADR-0060), por tarjeta. Solo mientras el
/// mes no tiene movimientos: sin esto, "Gastaste" el día 1 no tiene de dónde
/// salir. Tocar una tarjeta abre sus compras.
struct CarriedInCardsCard: View {
    @Environment(\.lana) private var lana
    let cards: [CarriedInCard]
    /// "septiembre": de cuándo son las compras.
    let previousMonthName: String
    let onSelect: (CarriedInCard) -> Void

    var body: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.p10.rawValue) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Gastaste con tarjetas de crédito")
                        .lanaFont(.bodyEmphasis)
                        .fontWeight(.regular)
                        .foregroundStyle(lana.ink70)
                    Spacer(minLength: Space.sm.rawValue)
                    Text(totalText)
                        .lanaFont(.cardAmount)
                        .foregroundStyle(lana.ink)
                }
                .padding(.bottom, Space.xs.rawValue)

                // Lo que se decidió gastar contra lo que ya se sabía que
                // venía: sin recurrentes no hay nada que separar.
                if cards.contains(where: { $0.recurringCount > 0 }) {
                    splitLine("Compras", amounts: cards.map {
                        Money(amount: $0.purchasesAmount, currency: $0.amount.currency)
                    })
                    splitLine("Recurrentes", amounts: cards.map {
                        Money(amount: $0.recurringAmount, currency: $0.amount.currency)
                    })
                    HairlineDivider()
                        .padding(.vertical, Space.xs.rawValue)
                }

                ForEach(cards) { item in
                    Button { onSelect(item) } label: { row(item) }
                        .buttonStyle(.plain)
                }

                Text("Las hiciste en \(previousMonthName) después del corte; se pagan este mes.")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink42)
                    .padding(.top, Space.xs.rawValue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row(_ item: CarriedInCard) -> some View {
        HStack(spacing: Space.p10.rawValue) {
            RoundedRectangle(cornerRadius: Radius.hairline.rawValue, style: .continuous)
                .fill(Color(hex: item.card.colorHex) ?? lana.accentFill)
                .frame(width: LanaMetrics.cardTickWidth, height: LanaMetrics.cardTickHeight)
            Text("\(item.card.alias) · \(CarriedInCardsCard.countText(item))")
                .lanaFont(.detail)
                .foregroundStyle(lana.ink70)
                .lineLimit(1)
            Spacer(minLength: Space.sm.rawValue)
            Text(MoneyDisplay.full(item.amount))
                .lanaFont(.detail)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(lana.ink)
            RowChevron()
        }
        .frame(minHeight: LanaMetrics.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Ver las compras")
    }

    /// "4 compras, 2 recurrentes", sin la parte que esté en cero.
    static func countText(_ item: CarriedInCard) -> String {
        var parts: [String] = []
        if item.purchaseCount > 0 {
            parts.append(item.purchaseCount == 1 ? "1 compra" : "\(item.purchaseCount) compras")
        }
        if item.recurringCount > 0 {
            parts.append(item.recurringCount == 1 ? "1 recurrente" : "\(item.recurringCount) recurrentes")
        }
        return parts.joined(separator: ", ")
    }

    private func splitLine(_ title: String, amounts: [Money]) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: Space.sm.rawValue)
            Text(Self.joinedTotals(amounts))
                .monospacedDigit()
        }
        .lanaFont(.detail)
        .foregroundStyle(lana.ink50)
    }

    private var totalText: String {
        Self.joinedTotals(cards.map(\.amount))
    }

    /// Suma por moneda, nunca entre monedas: "$8,719.27 · US$40.00".
    private static func joinedTotals(_ amounts: [Money]) -> String {
        Dictionary(grouping: amounts, by: \.currency)
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { currency, items in
                MoneyDisplay.full(Money(amount: items.reduce(Decimal(0)) { $0 + $1.amount }, currency: currency))
            }
            .joined(separator: " · ")
    }
}

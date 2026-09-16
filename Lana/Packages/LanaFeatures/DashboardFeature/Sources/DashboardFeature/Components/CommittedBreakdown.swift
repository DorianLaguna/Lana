import LanaCore
import LanaDesign
import SwiftUI

/// De qué está hecho "Te queda" (ADR-0046).
///
/// Tres pisos, en este orden: lo **comprometido** —solo los recurrentes que
/// faltan por cobrarse—, lo **libre** que queda de ellos, y aparte las
/// **tarjetas**, porque su dinero no sale igual: lo ya facturado se paga este
/// mes y lo del ciclo abierto se paga el que entra.
///
/// El total de abajo puede salir **negativo**, y ese es el dato: el mes no
/// cierra sin el ingreso que todavía no cae.
struct CommittedBreakdown: View {
    @Environment(\.lana) private var lana
    let commitments: MonthCommitments
    /// Lo que queda del mes, de donde se resta lo comprometido.
    let remaining: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if commitments.committed > 0 {
                split
            }

            if !dueCards.isEmpty {
                cardsDueBlock
                    .padding(.top, commitments.committed > 0 ? Space.p14.rawValue : 0)
            }

            if !nextMonthCards.isEmpty {
                nextMonthBlock
                    .padding(.top, Space.p14.rawValue)
            }

            if !commitments.justAfter.isEmpty {
                lookahead
                    .padding(.top, Space.p12.rawValue)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var dueCards: [MonthCommitments.CardBalance] {
        commitments.cards.filter { $0.dueThisMonth.amount > 0 }
    }

    private var nextMonthCards: [MonthCommitments.CardBalance] {
        commitments.cards.filter { $0.nextMonth.amount > 0 }
    }

    // MARK: - Comprometido y libre

    private var split: some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
                .padding(.bottom, Space.p12.rawValue)

            row(
                title: "Comprometido",
                amount: Money(amount: commitments.committed, currency: commitments.currency),
                isStrong: true)

            VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                ForEach(commitments.recurring, id: \.self) { commitment in
                    detailRow(
                        label: label(commitment.concept, date: commitment.date),
                        amount: abs(commitment.amount.amount))
                }
            }
            .padding(.top, Space.p6.rawValue)
            .padding(.bottom, Space.p12.rawValue)

            HairlineDivider()
                .padding(.bottom, Space.p12.rawValue)

            row(
                title: "Libre",
                amount: Money(amount: commitments.free(after: remaining), currency: commitments.currency),
                isStrong: true,
                isFree: true)
        }
    }

    // MARK: - Tarjetas

    /// Lo que se le debe a cada tarjeta **este mes**: ya está facturado, así que
    /// sale del dinero de este mes aunque su día límite ya haya pasado.
    private var cardsDueBlock: some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            SectionHeader("Tarjetas", style: .minor)

            ForEach(dueCards) { card in
                detailRow(label: cardLabel(card), amount: card.dueThisMonth.amount)
            }

            HairlineDivider()
                .padding(.vertical, Space.p6.rawValue)

            row(
                title: "Después de tarjetas",
                amount: Money(amount: commitments.afterCards(from: remaining), currency: commitments.currency),
                isStrong: true,
                isFree: true)
        }
    }

    /// Lo del ciclo abierto: se factura en el próximo corte, así que no se resta
    /// de este mes. Decirlo evita la sorpresa del mes que entra.
    private var nextMonthBlock: some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            Text("Para el mes que entra")
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
            ForEach(nextMonthCards) { card in
                detailRow(label: cardLabel(card), amount: card.nextMonth.amount, isMuted: true)
            }
        }
    }

    /// "Bancomer · corte día 23": el corte es lo que explica por qué una cifra
    /// es de este mes y la otra del siguiente.
    private func cardLabel(_ card: MonthCommitments.CardBalance) -> String {
        guard let cutoffDay = card.cutoffDay else { return card.card }
        return "\(card.card) · corte día \(cutoffDay)"
    }

    // MARK: - Piezas

    private func row(title: String, amount: Money, isStrong: Bool, isFree: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
            Text(title)
                .lanaFont(isStrong ? .bodyEmphasis : .rowSubtitle)
                .foregroundStyle(isFree ? lana.ink : lana.ink70)
            Spacer(minLength: Space.sm.rawValue)
            Text(MoneyDisplay.compact(amount))
                .lanaFont(isFree ? .statAmount : .rowAmount)
                .foregroundStyle(freeColor(amount, isFree: isFree))
        }
    }

    /// Un total en negativo no se pinta de alarma: es un dato, y el ritmo de
    /// abajo ya dice qué hacer con él (Docs/CLAUDE.md → Tono).
    private func freeColor(_ amount: Money, isFree: Bool) -> Color {
        guard isFree else { return lana.ink70 }
        return amount.amount < 0 ? lana.attention : lana.ink
    }

    private func detailRow(label: String, amount: Decimal, isMuted: Bool = false) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            Text(label)
                .lanaFont(.rowSubtitle)
                .foregroundStyle(isMuted ? lana.ink42 : lana.ink50)
                .lineLimit(1)
            Spacer(minLength: Space.xs.rawValue)
            Text(MoneyDisplay.compact(Money(amount: amount, currency: commitments.currency)))
                .lanaFont(.rowSubtitle)
                .monospacedDigit()
                .foregroundStyle(isMuted ? lana.ink42 : lana.ink70)
        }
    }

    private func label(_ concept: String, date: Date?) -> String {
        guard let date else { return concept }
        return "\(concept) · \(LanaDateFormat.dayLabel(date))"
    }

    /// Lo que cae justo pasando el mes. Se ve pero no se suma: si no, alguien a
    /// día 28 se gasta la renta del 1.
    private var lookahead: some View {
        VStack(alignment: .leading, spacing: Space.p2.rawValue) {
            ForEach(commitments.justAfter, id: \.self) { commitment in
                Text(lookaheadText(commitment))
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink42)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func lookaheadText(_ commitment: Commitment) -> String {
        let amount = Money(amount: abs(commitment.amount.amount), currency: commitment.amount.currency)
        let day = LanaDateFormat.dayLabel(commitment.date).lowercased()
        return "Y el \(day): \(commitment.concept) \(MoneyDisplay.compact(amount))"
    }
}

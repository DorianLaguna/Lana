import LanaCore
import LanaDesign
import SwiftUI

/// De qué está hecho "Te queda" (ADR-0046).
///
/// Lo **comprometido** —solo los recurrentes que faltan por cobrarse— y lo
/// **libre** que queda de ellos. Aparte, lo que se acumula en tarjetas para el
/// mes que entra, con su total, que se ve pero no se resta.
///
/// Lo que cae justo después del mes (ADR-0046, "y el 1 de octubre: Renta") ya
/// no se muestra: el dueño lo leyó como ruido del mes siguiente (ADR-0060).
///
/// Lo que ya se debe a las tarjetas este mes no tiene renglón propio: desde
/// ADR-0060, lo comprado con crédito ya cuenta en "Gastaste" del mes de su
/// corte, y restarlo aquí otra vez lo contaría dos veces.
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

            if !nextMonthCards.isEmpty {
                nextMonthBlock
                    .padding(.top, commitments.committed > 0 ? Space.p14.rawValue : 0)
            }
        }
        .accessibilityElement(children: .combine)
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
            // Con una sola tarjeta el total repetiría su renglón.
            if nextMonthCards.count > 1 {
                HairlineDivider()
                    .padding(.vertical, Space.p6.rawValue)
                row(
                    title: "Total de tarjetas",
                    amount: Money(amount: commitments.cardsNextMonth, currency: commitments.currency),
                    isStrong: false)
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
}

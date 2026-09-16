import LanaCore
import LanaDesign
import SwiftUI

/// De qué está hecho "Te queda": cuánto ya tiene dueño y cuánto queda libre
/// (ADR-0046).
///
/// Las tarjetas van en **un solo renglón** aunque sean varias: el detalle por
/// tarjeta ya vive en "Esta quincena", que es la sección que lleva a Tarjetas.
/// Repetirlo aquí tarjeta por tarjeta haría ver la misma deuda dos veces.
struct CommittedBreakdown: View {
    @Environment(\.lana) private var lana
    let commitments: MonthCommitments
    /// Lo que queda del mes, de donde se resta lo comprometido.
    let remaining: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sin nada comprometido no se parte nada: "Ya tiene dueño $0" y un
            // "Libre" que repite la cifra de arriba serían dos renglones para
            // no decir nada. Queda solo el pie de lo que viene.
            if commitments.committed > 0 {
                split
            }

            if !commitments.justAfter.isEmpty {
                lookahead
                    .padding(.top, commitments.committed > 0 ? Space.p12.rawValue : 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var split: some View {
        VStack(alignment: .leading, spacing: 0) {
            HairlineDivider()
                .padding(.bottom, Space.p12.rawValue)

            row(
                title: "Ya tiene dueño",
                amount: Money(amount: commitments.committed, currency: commitments.currency),
                isStrong: true)

            VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                ForEach(commitments.recurring, id: \.self) { commitment in
                    detailRow(concept: commitment.concept, date: commitment.date, amount: commitment.amount)
                }
                if commitments.cardsTotal > 0 {
                    detailRow(
                        concept: "Tarjetas",
                        date: nil,
                        amount: Money(amount: -commitments.cardsTotal, currency: commitments.currency))
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

    /// Lo libre en negativo no se pinta de alarma: es un dato, y el mensaje del
    /// ritmo ya dice qué hacer con él (Docs/CLAUDE.md → Tono).
    private func freeColor(_ amount: Money, isFree: Bool) -> Color {
        guard isFree else { return lana.ink70 }
        return amount.amount < 0 ? lana.attention : lana.ink
    }

    private func detailRow(concept: String, date: Date?, amount: Money) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            Text(label(concept: concept, date: date))
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink50)
                .lineLimit(1)
            Spacer(minLength: Space.xs.rawValue)
            Text(MoneyDisplay.compact(Money(amount: abs(amount.amount), currency: amount.currency)))
                .lanaFont(.rowSubtitle)
                .monospacedDigit()
                .foregroundStyle(lana.ink70)
        }
    }

    private func label(concept: String, date: Date?) -> String {
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

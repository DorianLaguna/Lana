import LanaCore
import LanaDesign
import SwiftUI

/// De qué está hecho "Te queda": cuánto está comprometido y cuánto queda libre
/// (ADR-0046).
///
/// Cada tarjeta va con su alias y su día límite, igual que un recurrente: "lo
/// que voy a pagar" es una pregunta por tarjeta, no un total anónimo.
///
/// Lo que se acumuló **después del corte** se muestra abajo y no se suma: esa
/// factura todavía no cierra, se paga el mes que entra y va a crecer mientras
/// se siga usando la tarjeta. Es el mismo vocabulario del detalle de tarjeta,
/// que ya separa "Para el corte" de "Después del corte".
struct CommittedBreakdown: View {
    @Environment(\.lana) private var lana
    let commitments: MonthCommitments
    /// Lo que queda del mes, de donde se resta lo comprometido.
    let remaining: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sin nada comprometido no se parte nada: "Comprometido $0" y un
            // "Libre" que repite la cifra de arriba serían dos renglones para
            // no decir nada.
            if commitments.committed > 0 {
                split
            }

            if !commitments.accruing.isEmpty {
                accruingBlock
                    .padding(.top, commitments.committed > 0 ? Space.p14.rawValue : 0)
            }

            if !commitments.justAfter.isEmpty {
                lookahead
                    .padding(.top, Space.p12.rawValue)
            }
        }
        .accessibilityElement(children: .combine)
    }

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
                    detailRow(concept: commitment.concept, date: commitment.date, amount: commitment.amount)
                }
                // Tarjeta por tarjeta, con su día límite: es lo que se va a
                // pagar de cada una este mes.
                ForEach(commitments.cards, id: \.self) { commitment in
                    detailRow(concept: commitment.concept, date: commitment.date, amount: commitment.amount)
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

    /// Lo acumulado en el ciclo abierto. Va apagado y fuera de la suma: decirlo
    /// como si fuera de este mes sería cobrar dos veces lo mismo.
    private var accruingBlock: some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            Text("Después del corte · se paga el mes que entra")
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(commitments.accruing) { charge in
                HStack(spacing: Space.sm.rawValue) {
                    Text(charge.card)
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink50)
                        .lineLimit(1)
                    Spacer(minLength: Space.xs.rawValue)
                    Text(MoneyDisplay.compact(charge.amount))
                        .lanaFont(.rowSubtitle)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink50)
                }
            }
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

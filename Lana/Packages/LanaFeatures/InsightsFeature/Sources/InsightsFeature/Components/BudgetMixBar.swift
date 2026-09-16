import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// "Cómo repartiste" (rediseño, sección 10): la barra apilada de la mezcla y
/// su leyenda, con la meta de la regla elegida al lado de cada grupo.
///
/// Rebasar una meta que el propio usuario eligió es un dato, no una falta: el
/// tramo nunca se pinta de alarma, la meta solo se dice.
struct BudgetMixBar: View {
    @Environment(\.lana) private var lana

    let shares: [BudgetShare]
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md.rawValue) {
            segmentedBar
            legend
        }
    }

    private var segmentedBar: some View {
        GeometryReader { proxy in
            HStack(spacing: Space.p3.rawValue) {
                ForEach(shares) { share in
                    Capsule()
                        .fill(color(for: share.group))
                        .frame(width: max(0, proxy.size.width * fraction(of: share)))
                }
                // Lo que falta para completar la barra: pista, no un cuarto
                // grupo.
                Capsule()
                    .fill(lana.surface3)
            }
        }
        .frame(height: LanaMetrics.barStacked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var legend: some View {
        VStack(spacing: 0) {
            ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                legendRow(share)
                if index < shares.count - 1 {
                    HairlineDivider()
                }
            }
        }
    }

    private func legendRow(_ share: BudgetShare) -> some View {
        HStack(spacing: Space.p10.rawValue) {
            Circle()
                .fill(color(for: share.group))
                .frame(width: LanaMetrics.dot, height: LanaMetrics.dot)
            VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                Text(share.group.displayName)
                    .lanaFont(.bodyEmphasis)
                    .fontWeight(.regular)
                    .foregroundStyle(lana.ink)
                Text(Money(amount: share.amount, currency: currency).formatted())
                    .lanaFont(.rowSubtitle)
                    .monospacedDigit()
                    .foregroundStyle(lana.ink42)
            }
            Spacer(minLength: Space.sm.rawValue)
            VStack(alignment: .trailing, spacing: Space.p2.rawValue) {
                Text(share.share.formatted(.percent.precision(.fractionLength(0))))
                    .lanaFont(.rowAmount)
                    .fontWeight(.semibold)
                    .foregroundStyle(lana.ink)
                if let target = share.target {
                    // La meta se dice con palabras además del número: el color
                    // nunca es el único portador de información.
                    Text("meta \(target.formatted(.percent.precision(.fractionLength(0))))")
                        .lanaFont(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink42)
                }
            }
        }
        .padding(.vertical, Space.p12.rawValue)
        .accessibilityElement(children: .combine)
    }

    private func fraction(of share: BudgetShare) -> CGFloat {
        // Un ahorro negativo (se gastó más de lo que entró) no dibuja tramo.
        guard share.share > 0 else { return 0 }
        return CGFloat(truncating: min(share.share, 1) as NSDecimalNumber)
    }

    private func color(for group: BudgetGroup) -> Color {
        switch group {
        case .necesidad: lana.accentFill
        case .deseo: lana.attention
        case .ahorro: lana.positive
        }
    }

    private var accessibilitySummary: String {
        shares
            .map { "\($0.group.displayName) \($0.share.formatted(.percent.precision(.fractionLength(0))))" }
            .joined(separator: ", ")
    }
}

#Preview {
    VStack(spacing: Space.lg.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            BudgetMixBar(
                shares: [
                    BudgetShare(
                        group: .necesidad,
                        amount: 5500,
                        share: Decimal(string: "0.55") ?? 0,
                        target: Decimal(string: "0.50")),
                    BudgetShare(
                        group: .deseo,
                        amount: 2500,
                        share: Decimal(string: "0.25") ?? 0,
                        target: Decimal(string: "0.30")),
                    BudgetShare(
                        group: .ahorro,
                        amount: 2000,
                        share: Decimal(string: "0.20") ?? 0,
                        target: Decimal(string: "0.20"))
                ],
                currency: .mxn)
                .padding(LanaMetrics.screenMargin)
                .background(LanaColors(theme: theme, colorScheme: .dark).surface)
                .lanaTheme(theme)
        }
    }
}

import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// La barra segmentada de la mezcla: cuánto se llevó cada grupo, y dónde
/// quedaría la meta de la regla elegida.
///
/// La meta se marca con una línea vertical sobre el tramo, no pintando el
/// tramo de rojo cuando se pasa: rebasar una meta que el propio usuario eligió
/// es un dato, no una falta (Docs/CLAUDE.md → Tono). `critical` se reserva para
/// donde hay algo que hacer.
struct BudgetMixBar: View {
    @Environment(\.lana) private var lana

    let shares: [BudgetShare]
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            segmentedBar
            VStack(spacing: 0) {
                ForEach(shares) { share in
                    legendRow(share)
                    if share.id != shares.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var segmentedBar: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(shares) { share in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color(for: share.group))
                        .frame(width: max(0, proxy.size.width * fraction(of: share)))
                }
                // Lo que falta para completar la barra cuando los tramos no
                // llegan al 100% — pista, no un cuarto grupo.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(lana.hairlineStrong.opacity(0.5))
            }
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// Calca la forma de `TransactionRow`, la fila más repetida de la app: un
    /// punto de color, una pila de dos líneas a la izquierda y otra a la
    /// derecha. Antes eran cuatro columnas en una línea —etiqueta, porcentaje,
    /// meta y monto— y a tamaños de accesibilidad no caben en el ancho de una
    /// pantalla.
    private func legendRow(_ share: BudgetShare) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            Circle()
                .fill(color(for: share.group))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(share.group.displayName)
                    .lanaFont(.body)
                    .foregroundStyle(lana.ink)
                Text(Money(amount: share.amount, currency: currency).formatted())
                    .lanaFont(.caption)
                    .monospacedDigit()
                    .foregroundStyle(lana.ink50)
            }
            Spacer(minLength: Space.sm.rawValue)
            VStack(alignment: .trailing, spacing: 2) {
                Text(share.share.formatted(.percent.precision(.fractionLength(0))))
                    .lanaFont(.body)
                    .monospacedDigit()
                    .foregroundStyle(lana.ink)
                if let target = share.target {
                    // La meta se dice con palabras además del número: el color
                    // nunca es el único portador de información.
                    Text("meta \(target.formatted(.percent.precision(.fractionLength(0))))")
                        .lanaFont(.caption)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink50)
                }
            }
        }
        .padding(.vertical, Space.xs.rawValue)
        .accessibilityElement(children: .combine)
    }

    private func fraction(of share: BudgetShare) -> CGFloat {
        // Un ahorro negativo (se gastó más de lo que entró) no dibuja tramo:
        // no hay barra que ocupe menos que nada.
        guard share.share > 0 else { return 0 }
        return CGFloat(truncating: min(share.share, 1) as NSDecimalNumber)
    }

    private func color(for group: BudgetGroup) -> Color {
        switch group {
        case .necesidad: lana.accent
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
            LanaCard {
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
            }
            .lanaTheme(theme)
        }
    }
    .padding(Space.md.rawValue)
}

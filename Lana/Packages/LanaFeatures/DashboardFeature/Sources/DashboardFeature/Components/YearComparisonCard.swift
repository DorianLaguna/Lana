import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// Las dos comparaciones del mes más reciente con movimientos: contra el mes
/// anterior y contra el mismo mes del año pasado.
///
/// El cambio se presenta con flecha y signo, no solo con color: el color nunca
/// es el único portador de información (Docs/CONVENTIONS.md → Reglas de UI).
/// Y ni "subió" ni "bajó" llevan `critical` — un gasto mayor es un dato, no una
/// alerta (Docs/CLAUDE.md → Tono).
struct YearComparisonCard: View {
    @Environment(\.lana) private var lana

    let title: String
    let previousMonth: PeriodDelta?
    let sameMonthLastYear: PeriodDelta?

    var body: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                SectionCaption(title)
                if let previousMonth {
                    row("Contra el mes anterior", delta: previousMonth)
                }
                if let sameMonthLastYear {
                    row("Contra el mismo mes del año pasado", delta: sameMonthLastYear)
                }
            }
        }
    }

    private func row(_ title: String, delta: PeriodDelta) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .lanaFont(.body)
                .foregroundStyle(lana.ink)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(Self.text(for: delta))
                    .lanaFont(.body)
                    .monospacedDigit()
                    .foregroundStyle(lana.ink)
                if let relative = delta.relative {
                    Text(relative.formatted(.percent.precision(.fractionLength(0))))
                        .lanaFont(.caption)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink50)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private static func text(for delta: PeriodDelta) -> String {
        let amount = Money(amount: abs(delta.absolute), currency: delta.currency).formatted()
        switch delta.direction {
        case .up: return "↑ \(amount)"
        case .down: return "↓ \(amount)"
        case .unchanged: return "Igual"
        }
    }
}

#Preview {
    VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            YearComparisonCard(
                title: "Septiembre",
                previousMonth: PeriodDelta(currency: .mxn, current: 5200, previous: 4400),
                sameMonthLastYear: PeriodDelta(currency: .mxn, current: 5200, previous: 6100))
                .lanaTheme(theme)
        }
    }
    .padding(Space.md.rawValue)
}

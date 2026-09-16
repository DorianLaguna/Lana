import LanaCore
import LanaDesign
import SwiftUI

/// La cifra que abre un drill-down de categoría o de forma de pago: sin
/// tarjeta, sobre el fondo, como "Debes en total" en el detalle de una tarjeta
/// (rediseño, sección 05). Debajo, cuántos gastos son y qué parte del periodo
/// pesan, con la barra de esa misma proporción.
struct DrillDownTotal: View {
    @Environment(\.lana) private var lana
    let label: String
    let amount: Money
    /// "11 gastos · 35% de tu mes".
    let summary: String
    /// La parte del periodo, en 0...1.
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .lanaFont(.sectionHeader)
                .foregroundStyle(lana.ink50)
                .padding(.bottom, Space.p6.rawValue)
            Text(amount.formatted())
                .lanaFont(.screenAmount)
                .foregroundStyle(lana.ink)
                .contentTransition(.numericText())
                .padding(.bottom, Space.xs.rawValue)
            Text(summary)
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
                .padding(.bottom, Space.p12.rawValue)
            ProgressTrack(fraction: share, height: LanaMetrics.barMedium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.xl.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                DrillDownTotal(
                    label: "Total en el mes",
                    amount: Money(amount: 3120, currency: .mxn),
                    summary: "11 gastos · 35% de tu mes",
                    share: 0.35)
                    .padding(LanaMetrics.screenMargin)
                    .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

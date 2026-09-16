import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// "Cómo repartiste" con su selector de regla (rediseño, sección 10).
///
/// Vive aparte de `InsightsView` por tamaño, igual que `AskSection`: es la
/// única sección de esa pantalla que tiene estado propio de presentación (el
/// menú de reglas) y se lee entera de un vistazo.
struct BudgetMixSection: View {
    @Environment(\.lana) private var lana

    let mix: BudgetMix
    let shares: [BudgetShare]
    let currency: Currency
    let selectedRule: BudgetRule?
    let onSelectRule: (BudgetRule?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader("Cómo repartiste", style: .minor)
                Spacer(minLength: Space.sm.rawValue)
                rulePicker
            }
            .padding(.bottom, Space.md.rawValue)

            BudgetMixBar(shares: shares, currency: currency)

            // Sin ingreso registrado no hay meta que perseguir: se dice, en vez
            // de inventar un denominador.
            if !mix.isMeasuredAgainstIncome {
                Text("Registra un ingreso para ver metas.")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink42)
                    .padding(.top, Space.sm.rawValue)
            }
            if mix.unclassified > 0 {
                Text("Sin clasificar: \(Money(amount: mix.unclassified, currency: currency).formatted())")
                    .lanaFont(.rowSubtitle)
                    .monospacedDigit()
                    .foregroundStyle(lana.ink42)
                    .padding(.top, Space.xs.rawValue)
            }
        }
    }

    /// Cambiar de regla es instantáneo: todas usan los mismos grupos, así que
    /// solo cambian las metas — no se reclasifica ni se vuelve a llamar al
    /// modelo.
    private var rulePicker: some View {
        Menu {
            Button("Sin regla") { onSelectRule(nil) }
            ForEach(BudgetRule.allCases) { rule in
                Button("\(rule.displayName) — \(rule.summary)") { onSelectRule(rule) }
            }
        } label: {
            HStack(spacing: Space.xs.rawValue) {
                Text(selectedRule?.displayName ?? "Sin regla")
                    .lanaFont(.footnote)
                Image(systemName: "chevron.down")
                    .lanaFont(.caption2)
            }
            .foregroundStyle(lana.attention)
        }
        .accessibilityLabel("Regla de presupuesto")
    }
}

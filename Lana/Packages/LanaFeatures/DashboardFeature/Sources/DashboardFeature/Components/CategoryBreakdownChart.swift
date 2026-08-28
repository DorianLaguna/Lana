import LanaCore
import LanaDesign
import SwiftUI

/// El desglose del mes por categoría (Docs/PLAN.md → Fase 6, Fase 6.5). El
/// color de cada categoría sale de `LanaColors.categoryRamp`, nunca elegido
/// por el usuario (ADR-0006) — el índice se deriva de un hash estable del
/// nombre (no del `Hashable` de Swift, que cambia de semilla en cada
/// corrida) para que la misma categoría tenga siempre el mismo color entre
/// sesiones. `DashboardFeature` no conoce el enum cerrado de 9 categorías
/// (vive en `LanaParsing`, una implementación concreta); este hash evita
/// esa dependencia sin perder consistencia visual.
///
/// Barras dibujadas a mano, no con `Charts` — cada una necesita ser
/// tocable para entrar al drill-down por categoría (`CategoryDetailView`),
/// y hacer eso tappable barra por barra con `Charts` es más complicado que
/// el problema que resuelve aquí (Fase 6.5, calca `Main.dc.html`).
public struct CategoryBreakdownChart: View {
    @Environment(\.lana) private var lana

    private let totals: [CategoryTotal]
    private let onSelect: (String) -> Void

    public init(totals: [CategoryTotal], onSelect: @escaping (String) -> Void) {
        self.totals = totals
        self.onSelect = onSelect
    }

    public var body: some View {
        if totals.isEmpty {
            EmptyStateView(systemImage: "chart.bar", title: "Sin gastos que desglosar")
        } else {
            VStack(spacing: Space.sm.rawValue) {
                ForEach(totals) { total in
                    Button {
                        onSelect(total.category)
                    } label: {
                        row(for: total)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(for total: CategoryTotal) -> some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            HStack {
                HStack(spacing: Space.xs.rawValue) {
                    Circle()
                        .fill(color(for: total.category))
                        .frame(width: 8, height: 8)
                    Text(total.category.capitalized)
                        .lanaFont(.body)
                        .foregroundStyle(lana.textPrimary)
                }
                Spacer()
                HStack(spacing: Space.xs.rawValue) {
                    Text(Money(amount: total.amount, currency: total.currency).formatted())
                        .lanaFont(.body)
                        .monospacedDigit()
                        .foregroundStyle(lana.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(lana.textSecondary.opacity(0.6))
                }
            }
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(lana.separator)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color(for: total.category))
                            .frame(width: proxy.size.width * fraction(of: total))
                    }
            }
            .frame(height: 6)
        }
    }

    private func fraction(of total: CategoryTotal) -> CGFloat {
        guard let max = totals.map(\.amount).max(), max > 0 else { return 0 }
        return CGFloat(truncating: (total.amount / max) as NSDecimalNumber)
    }

    private func color(for category: String) -> Color {
        lana.categoryRamp[category.lowercased().stableRampIndex]
    }
}

extension String {
    /// Si es una de las categorías cerradas, su índice ya es único por
    /// construcción (`SuggestedCategory.rampIndex`) — sin choques posibles
    /// entre categorías reales. Si no (una forma de pago, o texto libre
    /// que no coincide con ninguna), cae a un hash estable (djb2) como
    /// respaldo — el `Hashable` de Swift cambia de semilla en cada corrida
    /// del proceso y no sirve para esto. El módulo (12) tiene que
    /// coincidir con `LanaColors.categoryRamp.count`.
    var stableRampIndex: Int {
        if let known = SuggestedCategory(rawValue: self) {
            return known.rampIndex
        }
        var hash = 5381
        for scalar in unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash) % 12
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    CategoryBreakdownChart(totals: [
                        CategoryTotal(category: "despensa", amount: 2500, currency: .mxn),
                        CategoryTotal(category: "transporte", amount: 1200, currency: .mxn),
                        CategoryTotal(category: "comida", amount: 900, currency: .mxn),
                        CategoryTotal(category: "ocio", amount: 400, currency: .mxn)
                    ], onSelect: { _ in })
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

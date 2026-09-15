import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// El gasto de los doce meses del año, una barra por mes.
///
/// Dibujada a mano y no con `Charts`, por el mismo motivo que
/// `CategoryBreakdownChart`: cada barra tiene que ser tocable para saltar al
/// Dashboard de ese mes, y hacer eso barra por barra con `Charts` es más
/// complicado que el problema que resuelve aquí.
///
/// El mes más caro va en `highlight` y no en `critical`: es un dato, no una
/// alerta. `critical` se usa donde hay algo que hacer, no donde hay algo que
/// juzgar (Docs/CLAUDE.md → Tono).
public struct MonthlyBarsChart: View {
    @Environment(\.lana) private var lana
    /// A tamaños de accesibilidad, doce iniciales no caben en el ancho de una
    /// pantalla por más que se estire: se truncan o se encinan. Se ocultan, y
    /// no se pierde nada — el nombre completo del mes ya viaja en la etiqueta
    /// de VoiceOver, que es quien las necesita.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// El alto crece con el tipo en vez de quedarse fijo: si no, al subir
    /// Dynamic Type la etiqueta se come el espacio y las barras quedan como
    /// rayas. Encoger la fuente está prohibido
    /// (`.claude/skills/theming/SKILL.md`), así que crece el contenedor.
    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 132

    private let points: [MonthlyPoint]
    private let onSelect: (Date) -> Void

    public init(points: [MonthlyPoint], onSelect: @escaping (Date) -> Void) {
        self.points = points
        self.onSelect = onSelect
    }

    private var maxExpenses: Decimal {
        points.map(\.expenses).max() ?? 0
    }

    private var highestMonth: Date? {
        points.filter(\.hasActivity).max { $0.expenses < $1.expenses }?.month
    }

    public var body: some View {
        if points.allSatisfy({ !$0.hasActivity }) {
            EmptyStateView(systemImage: "chart.bar", title: "Sin movimientos este año")
        } else {
            VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                HStack(alignment: .bottom, spacing: Space.xs.rawValue) {
                    ForEach(points) { point in
                        Button {
                            onSelect(point.month)
                        } label: {
                            bar(for: point)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityLabel(for: point))
                        .accessibilityHint("Abre ese mes en el Dashboard")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .frame(height: chartHeight)

                // Las barras son tocables y nada más lo insinuaba. La app ya
                // usa captions así para explicar lo que no se ve (el vacío de
                // Recurrentes, por ejemplo).
                Text("Toca un mes para verlo en el Dashboard")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.textSecondary)
                    // Ya lo dice el `accessibilityHint` de cada barra; en
                    // VoiceOver esto sería la misma frase trece veces.
                    .accessibilityHidden(true)
            }
        }
    }

    private func bar(for point: MonthlyPoint) -> some View {
        // `contentShape` sobre el VStack completo: la barra se dibuja corta
        // cuando el mes gastó poco, pero el blanco táctil tiene que ser toda la
        // columna — 44pt mínimo (design-reviewer.md).
        VStack(spacing: Space.xs.rawValue) {
            GeometryReader { proxy in
                // La pista completa se dibuja siempre, para que los meses
                // vacíos sigan siendo tocables y no queden como huecos.
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(lana.separator.opacity(0.5))
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(point.month == highestMonth ? lana.highlight : lana.accent)
                            .frame(height: proxy.size.height * fraction(of: point))
                    }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Text(Self.initial(of: point.month))
                    .lanaFont(.caption)
                    .foregroundStyle(point.hasActivity ? lana.textSecondary : lana.textSecondary.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func fraction(of point: MonthlyPoint) -> CGFloat {
        guard maxExpenses > 0 else { return 0 }
        return CGFloat(truncating: (point.expenses / maxExpenses) as NSDecimalNumber)
    }

    private func accessibilityLabel(for point: MonthlyPoint) -> String {
        let month = point.month.formatted(.dateTime.month(.wide)).capitalized
        guard point.hasActivity else { return "\(month), sin movimientos" }
        let amount = Money(amount: point.expenses, currency: point.currency).formatted()
        return "\(month), \(amount)"
    }

    /// La inicial del mes, para que quepan doce etiquetas sin encimarse. El
    /// nombre completo vive en la etiqueta de VoiceOver, que sí tiene espacio.
    private static func initial(of month: Date) -> String {
        String(month.formatted(.dateTime.month(.narrow)).prefix(1)).uppercased()
    }
}

#Preview {
    let calendar = Calendar(identifier: .gregorian)
    let points = (1 ... 12).compactMap { month -> MonthlyPoint? in
        guard let date = calendar.date(from: DateComponents(year: 2026, month: month, day: 1)) else { return nil }
        let amounts: [Decimal] = [4200, 3100, 5600, 2400, 6900, 3800, 0, 4400, 5100, 2900, 3300, 7200]
        return MonthlyPoint(
            month: date,
            currency: .mxn,
            expenses: amounts[month - 1],
            income: 0,
            hasActivity: amounts[month - 1] > 0)
    }

    return ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    MonthlyBarsChart(points: points, onSelect: { _ in })
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

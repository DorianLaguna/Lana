import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// Los doce meses del año, una barra por mes (rediseño, sección 09).
///
/// Dibujada a mano y no con `Charts` porque cada barra tiene que ser tocable
/// para abrir ese mes, y hacerlo barra por barra con `Charts` es más
/// complicado que el problema que resuelve.
///
/// El color marca **qué destaca**, no qué es: el mes más caro va en
/// `attention` y el que se está viendo en Mes va en el acento. Los meses sin
/// movimiento se quedan como un muñón apagado — presentes pero callados, no
/// huecos.
public struct MonthlyBarsChart: View {
    @Environment(\.lana) private var lana
    /// A tamaños de accesibilidad, doce iniciales no caben por más que se
    /// estire el ancho. Se ocultan y no se pierde nada: el nombre completo
    /// viaja en la etiqueta de VoiceOver, que es quien las necesita.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// El alto crece con el tipo: si no, al subir Dynamic Type la etiqueta se
    /// come el espacio y las barras quedan como rayas.
    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = LanaMetrics.yearBarsHeight

    private let points: [MonthlyPoint]
    /// El mes que se está viendo en la pestaña Mes, para marcarlo.
    private let selectedMonth: Date?
    private let onSelect: (Date) -> Void

    public init(points: [MonthlyPoint], selectedMonth: Date? = nil, onSelect: @escaping (Date) -> Void) {
        self.points = points
        self.selectedMonth = selectedMonth
        self.onSelect = onSelect
    }

    private var maxExpenses: Decimal {
        points.map(\.expenses).max() ?? 0
    }

    private var highestMonth: Date? {
        points.filter(\.hasActivity).max { $0.expenses < $1.expenses }?.month
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            HStack(alignment: .bottom, spacing: Space.p5.rawValue) {
                ForEach(points) { point in
                    Button {
                        onSelect(point.month)
                    } label: {
                        bar(for: point)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: point))
                    .accessibilityHint("Abre ese mes")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .frame(height: chartHeight)

            Text("Toca un mes para abrirlo")
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink35)
                // Ya lo dice el hint de cada barra; en VoiceOver sería la
                // misma frase trece veces.
                .accessibilityHidden(true)
        }
    }

    private func bar(for point: MonthlyPoint) -> some View {
        // El blanco táctil es toda la columna aunque la barra salga corta.
        VStack(spacing: Space.p6.rawValue) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: Radius.bar.rawValue, style: .continuous)
                    .fill(color(for: point))
                    .frame(height: max(proxy.size.height * fraction(of: point), Radius.bar.rawValue))
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Text(LanaDateFormat.monthInitial(point.month))
                    .lanaFont(.axisLabel)
                    .foregroundStyle(labelColor(for: point))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func color(for point: MonthlyPoint) -> Color {
        guard point.hasActivity else { return lana.surface2 }
        if let selectedMonth, Calendar.current.isDate(point.month, equalTo: selectedMonth, toGranularity: .month) {
            return lana.accentFill
        }
        return point.month == highestMonth ? lana.attention : lana.ink28
    }

    private func labelColor(for point: MonthlyPoint) -> Color {
        guard point.hasActivity else { return lana.ink30 }
        if let selectedMonth, Calendar.current.isDate(point.month, equalTo: selectedMonth, toGranularity: .month) {
            return lana.accent
        }
        return point.month == highestMonth ? lana.attention : lana.ink42
    }

    /// Un mes sin movimiento se dibuja como un muñón, no como nada: sigue
    /// siendo tocable.
    private func fraction(of point: MonthlyPoint) -> CGFloat {
        guard point.hasActivity, maxExpenses > 0 else { return LanaMetrics.yearBarEmptyFraction }
        let fraction = CGFloat(truncating: (point.expenses / maxExpenses) as NSDecimalNumber)
        return max(fraction, LanaMetrics.yearBarEmptyFraction)
    }

    private func accessibilityLabel(for point: MonthlyPoint) -> String {
        let month = LanaDateFormat.monthName(point.month)
        guard point.hasActivity else { return "\(month), sin movimientos" }
        let amount = Money(amount: point.expenses, currency: point.currency).formatted()
        return "\(month), \(amount)"
    }
}

#Preview {
    let calendar = Calendar(identifier: .gregorian)
    let points = (1 ... 12).compactMap { month -> MonthlyPoint? in
        guard let date = calendar.date(from: DateComponents(year: 2026, month: month, day: 1)) else { return nil }
        let amounts: [Decimal] = [4200, 3100, 5600, 2400, 6900, 3800, 0, 19781, 9437, 0, 0, 0]
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
                MonthlyBarsChart(points: points, selectedMonth: points[8].month, onSelect: { _ in })
                    .padding(LanaMetrics.screenMargin)
                    .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

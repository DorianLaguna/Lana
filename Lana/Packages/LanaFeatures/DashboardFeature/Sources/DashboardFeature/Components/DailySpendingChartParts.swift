import Charts
import LanaCore
import LanaDesign
import SwiftUI

// MARK: - Ejes compartidos

/// Ejes y medidas de las gráficas de "Día a día". Las tres comparten el mismo
/// eje de días y el mismo ancho de etiquetas de monto: así el día 15 cae en la
/// misma vertical en todas.
@MainActor
enum DailyChartStyle {
    /// Media barra de margen a cada lado: la primera y la última no se cortan.
    static func domain(_ data: DailySpending) -> ClosedRange<Double> {
        0.5 ... Double(data.daysInMonth) + 0.5
    }

    static func double(_ amount: Decimal) -> Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }

    /// Una marca por semana: el último día pegado al borde se cortaba.
    static func dayAxis(_ lana: LanaColors) -> some AxisContent {
        AxisMarks(values: [1, 8, 15, 22, 29]) { value in
            AxisValueLabel {
                if let day = value.as(Double.self) {
                    Text("\(Int(day))")
                        .lanaFont(.caption2)
                        .foregroundStyle(lana.ink42)
                        .fixedSize()
                }
            }
        }
    }

    /// Los montos a la derecha y con ancho fijo.
    static func amountAxis(_ lana: LanaColors, currency: Currency, desiredCount: Int = 3) -> some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: desiredCount)) { value in
            AxisGridLine()
                .foregroundStyle(lana.hairline)
            AxisValueLabel {
                if let amount = value.as(Double.self) {
                    Text(DailySpendingSection.axisLabel(amount, currency: currency))
                        .lanaFont(.caption2)
                        .foregroundStyle(lana.ink42)
                        .frame(width: LanaMetrics.chartAxisLabelWidth, alignment: .trailing)
                }
            }
        }
    }

    /// El nombre de una serie al final de su línea: no hay que ir a la
    /// leyenda para saber cuál es cuál.
    static func endLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .lanaFont(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .fixedSize()
    }
}

// MARK: - Leyenda

/// Cómo se dibuja una entrada de la leyenda.
enum DailyLegendStyle {
    /// Una línea; `dash` vacío es continua.
    case line(Color, dash: [CGFloat])
    /// Un área con su borde arriba.
    case area
}

/// Qué es cada trazo, por color y por forma: nunca solo por color.
struct DailySpendingLegend: View {
    struct Entry: Identifiable {
        let label: String
        let style: DailyLegendStyle
        var id: String {
            label
        }
    }

    @Environment(\.lana) private var lana
    let entries: [Entry]

    var body: some View {
        FlowLayout(spacing: .md) {
            ForEach(entries) { entry in
                HStack(spacing: Space.xs.rawValue) {
                    switch entry.style {
                    case let .line(color, dash):
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: LanaMetrics.outline / 2))
                            path.addLine(to: CGPoint(x: Space.p18.rawValue, y: LanaMetrics.outline / 2))
                        }
                        .stroke(color, style: StrokeStyle(lineWidth: LanaMetrics.outline, lineCap: .round, dash: dash))
                        .frame(width: Space.p18.rawValue, height: LanaMetrics.outline)
                    case .area:
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(lana.accentFill)
                                .frame(height: LanaMetrics.outline)
                            Rectangle()
                                .fill(lana.accentSoft)
                        }
                        .frame(width: Space.p18.rawValue, height: LanaMetrics.cardTickWidth * 2)
                    }
                    Text(entry.label)
                }
            }
        }
        .lanaFont(.rowSubtitle)
        .foregroundStyle(lana.ink50)
        .accessibilityHidden(true)
    }
}

// MARK: - Recurrentes

/// Los recurrentes en su propia gráfica, debajo de lo gastado. Van aparte
/// porque cuentan distinto: **por corte**, lo que se paga este mes (lo del mes
/// anterior que cerró en este corte entra el día 1), mientras que lo gastado va
/// por fecha de compra. Encimados invitaban a compararlos.
///
/// Este mes: área con borde continuo hasta hoy y borde a guiones desde hoy —lo
/// que falta por caer—. Lo que ya es del mes siguiente, gris y a puntos. Cada
/// línea lleva su nombre al final.
struct DailyRecurringBlock: View {
    @Environment(\.lana) private var lana
    let model: DashboardModel
    let data: DailySpending
    let selectedDay: Int?
    @Binding var selection: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Recurrentes", style: .minor)
                .padding(.bottom, Space.sm.rawValue)
            Text(summary)
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink70)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Space.p12.rawValue)
            chart
                .frame(height: LanaMetrics.dailyRecurringChartHeight)
                .padding(.bottom, Space.sm.rawValue)
            DailySpendingLegend(entries: legendEntries)
        }
    }

    private var paid: Decimal {
        data.recurringCumulative.last?.amount ?? 0
    }

    private var total: Decimal {
        data.upcomingRecurringCumulative.last?.amount ?? paid
    }

    private var nextMonthTotal: Decimal {
        data.nextMonthRecurringCumulative.last?.amount ?? 0
    }

    private var nextMonthName: String {
        let next = model.calendar.date(byAdding: .month, value: 1, to: model.month) ?? model.month
        return LanaDateFormat.monthNameLowercased(next)
    }

    private var monthName: String {
        LanaDateFormat.monthNameLowercased(model.month)
    }

    /// "En octubre pagas $9,032 de recurrentes: $3,682 ya cobrados y $5,350
    /// por caer. $258 más ya son de noviembre." Con un día elegido, lo de ese
    /// día.
    private var summary: String {
        if let day = selectedDay {
            let amount = money(data.recurringSpent(through: day))
            return day <= data.lastDay
                ? "Al \(day) de \(monthName) llevabas \(amount) de recurrentes"
                : "Para el \(day) de \(monthName) llevarás \(amount) de recurrentes"
        }
        var text = "En \(monthName) pagas \(money(total)) de recurrentes"
        if total > paid {
            text += ": \(money(paid)) ya cobrados y \(money(total - paid)) por caer."
        } else {
            text += "."
        }
        if nextMonthTotal > 0 {
            text += " \(money(nextMonthTotal)) más ya son de \(nextMonthName)."
        }
        return text
    }

    private var legendEntries: [DailySpendingLegend.Entry] {
        var entries = [DailySpendingLegend.Entry(label: "cobrado", style: .area)]
        if !data.upcomingRecurringCumulative.isEmpty {
            let dashed = DailyLegendStyle.line(lana.accentFill, dash: LanaMetrics.chartReferenceDash)
            entries.append(.init(label: "por caer", style: dashed))
        }
        if !data.nextMonthRecurringCumulative.isEmpty {
            entries.append(.init(label: "para \(nextMonthName)", style: .line(lana.ink50, dash: LanaMetrics.chartDots)))
        }
        return entries
    }

    private var chart: some View {
        Chart {
            paidMarks
            upcomingMarks
            nextMonthMarks
            if let day = selectedDay {
                RuleMark(x: .value("Día", Double(day)))
                    .foregroundStyle(lana.hairlineStrong)
            }
        }
        .chartXScale(domain: DailyChartStyle.domain(data))
        // Su propia escala, con aire arriba para el nombre de la línea: con
        // la automática, $9k quedaba aplastado bajo un tope de $20k.
        .chartYScale(domain: 0 ... DailyChartStyle.double(max(total, nextMonthTotal)) * Self.headroom)
        .chartXAxis { DailyChartStyle.dayAxis(lana) }
        .chartYAxis { DailyChartStyle.amountAxis(lana, currency: data.currency, desiredCount: 2) }
        .chartXSelection(value: $selection)
        .accessibilityLabel("Recurrentes de \(monthName)")
        .accessibilityValue(summary)
    }

    @ChartContentBuilder
    private var paidMarks: some ChartContent {
        ForEach(data.recurringCumulative) { point in
            AreaMark(
                x: .value("Día", Double(point.day)),
                y: .value("Cobrado", DailyChartStyle.double(point.amount)),
                series: .value("Parte", "cobrado"),
                stacking: .unstacked)
                .foregroundStyle(lana.accentSoft)
                .interpolationMethod(.stepEnd)
            LineMark(
                x: .value("Día", Double(point.day)),
                y: .value("Cobrado", DailyChartStyle.double(point.amount)),
                series: .value("Borde", "cobrado"))
                .foregroundStyle(lana.accentFill)
                .lineStyle(StrokeStyle(lineWidth: LanaMetrics.outline))
                .interpolationMethod(.stepEnd)
        }
    }

    @ChartContentBuilder
    private var upcomingMarks: some ChartContent {
        ForEach(data.upcomingRecurringCumulative) { point in
            LineMark(
                x: .value("Día", Double(point.day)),
                y: .value("Por caer", DailyChartStyle.double(point.amount)),
                series: .value("Borde", "por caer"))
                .foregroundStyle(lana.accentFill)
                .lineStyle(StrokeStyle(lineWidth: LanaMetrics.outline, dash: LanaMetrics.chartReferenceDash))
                .interpolationMethod(.stepEnd)
        }
        if let last = data.upcomingRecurringCumulative.last ?? data.recurringCumulative.last {
            PointMark(x: .value("Día", Double(last.day)), y: .value("Total", DailyChartStyle.double(last.amount)))
                .symbolSize(0)
                .annotation(position: .top, alignment: .trailing, spacing: Space.xs.rawValue) {
                    DailyChartStyle.endLabel(monthName, color: lana.accent)
                }
        }
    }

    @ChartContentBuilder
    private var nextMonthMarks: some ChartContent {
        ForEach(data.nextMonthRecurringCumulative) { point in
            LineMark(
                x: .value("Día", Double(point.day)),
                y: .value("Mes siguiente", DailyChartStyle.double(point.amount)),
                series: .value("Borde", "mes siguiente"))
                .foregroundStyle(lana.ink50)
                .lineStyle(StrokeStyle(lineWidth: LanaMetrics.outline, lineCap: .round, dash: LanaMetrics.chartDots))
                .interpolationMethod(.stepEnd)
        }
        if let last = data.nextMonthRecurringCumulative.last {
            PointMark(x: .value("Día", Double(last.day)), y: .value("Total", DailyChartStyle.double(last.amount)))
                .symbolSize(0)
                .annotation(position: .top, alignment: .trailing, spacing: Space.xs.rawValue) {
                    DailyChartStyle.endLabel(nextMonthName, color: lana.ink50)
                }
        }
    }

    private func money(_ amount: Decimal) -> String {
        MoneyDisplay.whole(Money(amount: amount, currency: data.currency))
    }

    /// Cuánto más alto que el máximo llega el eje.
    private static let headroom = 1.3
}

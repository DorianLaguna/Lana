import Charts
import LanaCore
import LanaDesign
import SwiftUI

/// "Día a día" en Mes: lo acumulado contra el mes anterior y, debajo, lo
/// gastado cada día. Las dos gráficas comparten el eje de días y la selección:
/// tocar o arrastrar sobre cualquiera marca ese día en ambas, con su etiqueta
/// arriba de la gráfica —el dedo tapa la barra—, y debajo se abre lo que se
/// gastó ese día. El día se queda marcado al soltar.
///
/// Un solo acento (theming): este mes en `accentFill` con trazo continuo, el
/// anterior en tinta apagada y punteado —el guion lo distingue sin depender
/// del color—, cada uno con su nombre al final de la línea, y el día más caro
/// en `attention`. Los recurrentes van en su propio bloque al final
/// (`DailyRecurringBlock`): cuentan por corte y lo gastado por fecha de
/// compra; en la misma gráfica invitaban a compararlos.
struct DailySpendingSection: View {
    @Environment(\.lana) private var lana
    let model: DashboardModel
    /// Tocar un gasto del día lo abre para editar, como en el resto de Mes.
    let onSelectExpense: (Expense) -> Void
    @State private var excludingRecurring = false
    /// Lo que entrega `chartXSelection`: una posición continua sobre el eje,
    /// que vuelve a `nil` al levantar el dedo.
    @State private var selection: Double?
    /// El día marcado. A diferencia de `selection`, sobrevive al soltar: es
    /// el que se lee y el que abre su lista.
    @State private var selectedDay: Int?
    /// Qué momento es "hoy"; fijo solo en vistas previas.
    private let asOf: Date?

    /// - Parameters:
    ///   - selectedDay: el día que arranca marcado; para vistas previas.
    ///   - asOf: "hoy"; para vistas previas.
    init(
        model: DashboardModel,
        selectedDay: Int? = nil,
        asOf: Date? = nil,
        onSelectExpense: @escaping (Expense) -> Void) {
        self.model = model
        self.asOf = asOf
        self.onSelectExpense = onSelectExpense
        _selectedDay = State(initialValue: selectedDay)
    }

    var body: some View {
        if let data = model.dailySpending(excludingRecurring: excludingRecurring, asOf: asOf ?? Date()) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Día a día")
                    .padding(.bottom, Space.md.rawValue)

                if model.hasRecurringSpending {
                    Picker("Qué incluir", selection: $excludingRecurring) {
                        Text("Todo").tag(false)
                        Text("Sin recurrentes").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.bottom, Space.md.rawValue)
                }

                Text(readout(data))
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink70)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Space.p12.rawValue)
                    .contentTransition(.numericText())

                cumulativeChart(data)
                    .frame(height: LanaMetrics.dailyLineChartHeight)
                    .padding(.bottom, Space.sm.rawValue)
                DailySpendingLegend(entries: monthEntries)
                    .padding(.bottom, Space.p18.rawValue)

                dailyChart(data)
                    .frame(height: LanaMetrics.dailyBarsChartHeight)
                    .padding(.bottom, Space.sm.rawValue)
                if let day = selectedDay {
                    DailySpendingDayDetail(
                        model: model,
                        day: day,
                        data: data,
                        excludingRecurring: excludingRecurring,
                        onClose: { selectedDay = nil },
                        onSelectExpense: onSelectExpense)
                        .padding(.top, Space.md.rawValue)
                } else {
                    if let peak = data.peak {
                        Text("Tu día más caro: \(dayLabel(peak.day)) · \(money(peak.amount, data))")
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.ink50)
                    }
                    Text("Toca un día para ver qué gastaste.")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                        .padding(.top, Space.xs.rawValue)
                }

                if !excludingRecurring, data.recurringSpent(through: data.daysInMonth) > 0
                    || !data.nextMonthRecurringCumulative.isEmpty {
                    DailyRecurringBlock(model: model, data: data, selectedDay: selectedDay, selection: $selection)
                        .padding(.top, Space.p28.rawValue)
                }
            }
            .padding(.bottom, Space.p30.rawValue)
            .onChange(of: selection) {
                // Solo se actualiza mientras hay dedo: al soltar se queda.
                if let selection {
                    let day = Int(selection.rounded())
                    selectedDay = min(max(day, 1), data.daysInMonth)
                }
            }
            .onChange(of: model.month) { selectedDay = nil }
            .animation(.easeOut(duration: 0.2), value: selectedDay)
        }
    }

    // MARK: - Gráficas

    private func cumulativeChart(_ data: DailySpending) -> some View {
        Chart {
            ForEach(data.previousCumulative) { point in
                LineMark(
                    x: .value("Día", Double(point.day)),
                    y: .value("Llevabas", Self.double(point.amount)),
                    series: .value("Mes", "anterior"))
                    .foregroundStyle(lana.ink35)
                    .lineStyle(StrokeStyle(
                        lineWidth: LanaMetrics.outline,
                        lineCap: .round,
                        dash: LanaMetrics.chartReferenceDash))
            }
            ForEach(data.cumulative) { point in
                LineMark(
                    x: .value("Día", Double(point.day)),
                    y: .value("Llevas", Self.double(point.amount)),
                    series: .value("Mes", "este"))
                    .foregroundStyle(lana.accentFill)
                    .lineStyle(StrokeStyle(lineWidth: LanaMetrics.outline, lineCap: .round, lineJoin: .round))
            }
            endLabels(data)
            if let day = selectedDay {
                RuleMark(x: .value("Día", Double(day)))
                    .foregroundStyle(lana.hairlineStrong)
                    // Arriba y no junto al dedo: así se ve qué día se toca.
                    .annotation(
                        position: .top,
                        spacing: 0,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            dayTag(day)
                        }
                if day <= data.lastDay {
                    PointMark(
                        x: .value("Día", Double(day)),
                        y: .value("Llevas", Self.double(data.spent(through: day))))
                        .foregroundStyle(lana.accentFill)
                        .symbolSize(Self.markerArea)
                }
            }
        }
        .chartXScale(domain: DailyChartStyle.domain(data))
        .chartXAxis { DailyChartStyle.dayAxis(lana) }
        .chartYAxis { DailyChartStyle.amountAxis(lana, currency: data.currency) }
        .chartXSelection(value: $selection)
        .accessibilityLabel("Lo acumulado este mes contra el anterior")
        .accessibilityValue(readout(data))
    }

    private func dailyChart(_ data: DailySpending) -> some View {
        let peakDay = data.peak?.day
        return Chart {
            ForEach(data.daily.filter { $0.amount > 0 }) { point in
                bar(point, peakDay: peakDay)
            }
        }
        .chartXScale(domain: DailyChartStyle.domain(data))
        .chartXAxis(.hidden)
        .chartYAxis { DailyChartStyle.amountAxis(lana, currency: data.currency, desiredCount: 2) }
        .chartXSelection(value: $selection)
        .accessibilityLabel("Lo gastado cada día")
        .accessibilityValue(data.peak.map { "El día más caro fue el \($0.day)" } ?? "Sin gastos")
    }

    private func bar(_ point: DailySpending.Point, peakDay: Int?) -> some ChartContent {
        let center = Double(point.day)
        let start: PlottableValue<Double> = .value("Día", center - Self.barHalfWidth)
        let end: PlottableValue<Double> = .value("Día", center + Self.barHalfWidth)
        let base: PlottableValue<Double> = .value("Gastaste", 0)
        let top: PlottableValue<Double> = .value("Gastaste", Self.double(point.amount))
        return RectangleMark(xStart: start, xEnd: end, yStart: base, yEnd: top)
            .foregroundStyle(barColor(point.day, peakDay: peakDay))
            .cornerRadius(Radius.hairline.rawValue)
    }

    /// "14 oct" en una píldora, sobre la línea del día elegido.
    private func dayTag(_ day: Int) -> some View {
        Text("\(day) \(LanaDateFormat.monthNameLowercased(model.month).prefix(3))")
            .lanaFont(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(lana.ink)
            .padding(.horizontal, Space.sm.rawValue)
            .padding(.vertical, Space.xs.rawValue)
            .background(lana.surface3, in: Capsule())
    }

    /// Con un día elegido, el resto se apaga para que se lea cuál es.
    private func barColor(_ day: Int, peakDay: Int?) -> Color {
        if let selectedDay, selectedDay != day {
            return lana.ink28
        }
        return day == peakDay ? lana.attention : lana.accentFill
    }

    // MARK: - Nombres

    /// Cada línea con su nombre al final, en su color: "octubre" donde
    /// termina hoy, "septiembre" al final del mes.
    @ChartContentBuilder
    private func endLabels(_ data: DailySpending) -> some ChartContent {
        if let last = data.cumulative.last {
            PointMark(x: .value("Día", Double(last.day)), y: .value("Llevas", Self.double(last.amount)))
                .symbolSize(0)
                .annotation(position: .top, alignment: .trailing, spacing: Space.xs.rawValue) {
                    DailyChartStyle.endLabel(LanaDateFormat.monthNameLowercased(model.month), color: lana.accent)
                }
        }
        if let last = data.previousCumulative.last,
           let previous = model.calendar.date(byAdding: .month, value: -1, to: model.month) {
            PointMark(x: .value("Día", Double(last.day)), y: .value("Llevabas", Self.double(last.amount)))
                .symbolSize(0)
                .annotation(position: .bottom, alignment: .trailing, spacing: Space.xs.rawValue) {
                    DailyChartStyle.endLabel(LanaDateFormat.monthNameLowercased(previous), color: lana.ink50)
                }
        }
    }

    private var monthEntries: [DailySpendingLegend.Entry] {
        var entries = [DailySpendingLegend.Entry(
            label: LanaDateFormat.monthNameLowercased(model.month), style: .line(lana.accentFill, dash: []))]
        if let previous = model.calendar.date(byAdding: .month, value: -1, to: model.month) {
            entries.append(.init(
                label: LanaDateFormat.monthNameLowercased(previous),
                style: .line(lana.ink35, dash: LanaMetrics.chartReferenceDash)))
        }
        return entries
    }

    // MARK: - Texto

    /// Sin día elegido, cómo va el mes contra el anterior; con uno, ese día.
    /// Se dice como dato, sin juicio (Docs/CLAUDE.md → Tono).
    private func readout(_ data: DailySpending) -> String {
        let previousName = model.calendar.date(byAdding: .month, value: -1, to: model.month)
            .map { LanaDateFormat.monthNameLowercased($0) } ?? ""
        if let day = selectedDay {
            guard day <= data.lastDay else { return "\(dayLabel(day)) · todavía no llega" }
            let spentThatDay = data.daily.first { $0.day == day }?.amount ?? 0
            let soFar = money(data.spent(through: day), data)
            var text = "\(dayLabel(day)) · gastaste \(money(spentThatDay, data)) · llevabas \(soFar)"
            if let previous = data.previousSpent(through: day) {
                text += " (en \(previousName): \(money(previous, data)))"
            }
            return text
        }
        let spent = data.spent(through: data.lastDay)
        let verb = data.lastDay < data.daysInMonth ? "Llevas" : "Gastaste"
        guard let previous = data.previousSpent(through: data.lastDay) else {
            return "\(verb) \(money(spent, data))"
        }
        let difference = spent - previous
        let when = data.lastDay < data.daysInMonth ? " al día \(data.lastDay)" : ""
        if difference == 0 {
            return "\(verb) \(money(spent, data)) · lo mismo que en \(previousName)\(when)"
        }
        let comparison = difference > 0 ? "más" : "menos"
        let gap = money(abs(difference), data)
        return "\(verb) \(money(spent, data)) · \(gap) \(comparison) que en \(previousName)\(when)"
    }

    private func dayLabel(_ day: Int) -> String {
        "\(day) de \(LanaDateFormat.monthNameLowercased(model.month))"
    }

    private func money(_ amount: Decimal, _ data: DailySpending) -> String {
        MoneyDisplay.whole(Money(amount: amount, currency: data.currency))
    }

    // MARK: - Medidas de las gráficas

    /// Media barra, en días: cada una ocupa el 70% de su día y deja el
    /// espacio entre barras que pide una gráfica de barras delgadas.
    private static let barHalfWidth = 0.35
    /// Área del punto del día elegido (≥ 8 pt de diámetro).
    private static let markerArea: CGFloat = 64

    static func double(_ amount: Decimal) -> Double {
        DailyChartStyle.double(amount)
    }

    /// "$15k", "$800": el eje solo orienta; la cifra exacta va en el texto.
    static func axisLabel(_ amount: Double, currency: Currency) -> String {
        guard amount >= 1000 else {
            return MoneyDisplay.whole(Money(amount: Decimal(amount), currency: currency))
        }
        let thousands = Decimal((amount / 1000).rounded())
        return MoneyDisplay.whole(Money(amount: thousands, currency: currency)) + "k"
    }
}

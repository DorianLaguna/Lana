import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// La vista anual: el año completo en estadísticas puras, sin IA de por medio
/// — funciona igual en un dispositivo sin Apple Intelligence.
///
/// Se entra desde el Dashboard y se empuja en **su** `NavigationStack`, así que
/// esta vista no arma uno propio: avisa hacia arriba con callbacks a dónde
/// quiere navegar. Sin lógica propia — refleja `YearModel`
/// (Docs/ARCHITECTURE.md).
///
/// **El orden importa.** Abre con la cifra que la pantalla vino a contestar
/// (`HeroAmount`), sigue con lo que se mira seguido —los doce meses, las
/// comparaciones, los desgloses— y guarda la cola larga detrás de "Más
/// detalle", plegada. Antes eran nueve tarjetas idénticas apiladas y todas
/// pesaban lo mismo, que es como decir que ninguna pesaba.
public struct YearView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: YearModel
    /// Plegado por default, mismo criterio que `RecurringItemsSection`: lo que
    /// se consulta de vez en cuando no tiene que ocupar scroll cada vez.
    @State private var isDetailExpanded = false

    private let onSelectMonth: (Date) -> Void
    private let onSelectCategory: (String) -> Void
    private let onSelectPaymentMethod: (String) -> Void

    public init(
        model: YearModel,
        onSelectMonth: @escaping (Date) -> Void = { _ in },
        onSelectCategory: @escaping (String) -> Void = { _ in },
        onSelectPaymentMethod: @escaping (String) -> Void = { _ in }) {
        self.model = model
        self.onSelectMonth = onSelectMonth
        self.onSelectCategory = onSelectCategory
        self.onSelectPaymentMethod = onSelectPaymentMethod
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Space.md.rawValue) {
                YearSelector(
                    year: model.year,
                    onPrevious: { Task { await model.goToPreviousYear() } },
                    onNext: { Task { await model.goToNextYear() } })

                if model.statistics.currencies.isEmpty {
                    // Suprimido mientras carga: si no, parpadea "sin
                    // movimientos" antes de que lleguen los datos — mismo
                    // idiom que `CardsView` y `SharedListView`.
                    if !model.isLoading {
                        EmptyStateView(
                            systemImage: "chart.bar",
                            title: "Sin movimientos este año",
                            message: "Cuando registres algo, aparece aquí.")
                    }
                } else {
                    // Un bloque completo por moneda: nunca un total que las
                    // cruce (Docs/CONVENTIONS.md → Multi-moneda).
                    ForEach(model.statistics.currencies, id: \.rawValue) { currency in
                        currencyBlock(currency)
                    }
                }
            }
            .padding(Space.md.rawValue)
            .floatingMicClearance()
        }
        .background(lana.surface)
        .navigationTitle("El año")
        .task { await model.onAppear() }
        .refreshable { await model.onAppear() }
    }

    @ViewBuilder
    private func currencyBlock(_ currency: Currency) -> some View {
        // Con una sola moneda —el caso normal— el encabezado sobra y solo
        // sería ruido. Con dos, sin él las dieciocho tarjetas se leen como una
        // sola lista y no se ve dónde termina una moneda y empieza la otra.
        if model.statistics.currencies.count > 1 {
            Text(currency.rawValue)
                .lanaFont(.headline)
                .foregroundStyle(lana.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Space.sm.rawValue)
        }
        heroSection(currency)
        monthsSection(currency)
        comparisonsSection(currency)
        breakdownSection("Por categoría", totals: categoryTotals(currency), onSelect: onSelectCategory)
        incomeSection(currency)
        detailSection(currency)
    }

    // MARK: - El héroe

    /// La cifra que la pantalla vino a contestar, en la forma con la que abren
    /// todos los drill-downs de la app. Ingresos y tasa de ahorro van debajo,
    /// en la misma tarjeta y detrás de una línea: son del mismo dato, y en dos
    /// tarjetas grises separadas quedaban desconectados (mismo razonamiento que
    /// el resumen del mes en `DashboardView`).
    @ViewBuilder
    private func heroSection(_ currency: Currency) -> some View {
        if let total = model.statistics.period.total(in: currency) {
            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    HeroAmount(
                        label: "Gastado en \(model.year)",
                        amount: Money(amount: total.expenses, currency: currency).formatted(),
                        context: monthsWithActivityLabel(currency))

                    if !secondaryRows(currency, total: total).isEmpty {
                        Divider()
                        StatRowGroup(secondaryRows(currency, total: total))
                    }
                }
            }
        }
    }

    private func secondaryRows(_ currency: Currency, total: PeriodTotal) -> [StatRowGroup.Row] {
        var rows: [StatRowGroup.Row] = []
        if total.income > 0 {
            rows.append(StatRowGroup.Row(
                title: "Ingresos",
                value: Money(amount: total.income, currency: currency).formatted()))
        }
        // Solo con ingreso registrado: sin denominador la tasa de ahorro no
        // existe, y un 0% sería un dato falso en vez de su ausencia.
        if let rate = model.statistics.period.savingsRate(in: currency) {
            rows.append(StatRowGroup.Row(
                title: "Tasa de ahorro",
                value: rate.formatted(.percent.precision(.fractionLength(0)))))
        }
        return rows
    }

    private func monthsWithActivityLabel(_ currency: Currency) -> String {
        let active = model.statistics.monthlyPoints(in: currency).count(where: \.hasActivity)
        return active == 1 ? "1 mes con movimiento" : "\(active) meses con movimiento"
    }

    // MARK: - Los doce meses

    private func monthsSection(_ currency: Currency) -> some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                SectionCaption("Mes a mes")
                MonthlyBarsChart(points: model.statistics.monthlyPoints(in: currency), onSelect: onSelectMonth)

                if !monthRows(currency).isEmpty {
                    Divider()
                    StatRowGroup(monthRows(currency))
                }
            }
        }
    }

    /// El promedio y los extremos. La fila "Mes más caro" es además lo que hace
    /// legítimo que `MonthlyBarsChart` marque esa barra solo con color: el dato
    /// también viaja en texto, así que el tono no es el único portador
    /// (Docs/CONVENTIONS.md). Si algún día se quita esta fila, hay que darle al
    /// gráfico otra forma de decirlo.
    private func monthRows(_ currency: Currency) -> [StatRowGroup.Row] {
        var rows: [StatRowGroup.Row] = []
        if let average = model.statistics.monthlyAverage(in: currency) {
            rows.append(StatRowGroup.Row(
                title: "Promedio mensual",
                value: Money(amount: average, currency: currency).formatted()))
        }
        if let extremes = model.statistics.extremes(in: currency) {
            rows.append(StatRowGroup.Row(title: "Mes más caro", value: Self.describe(extremes.highest)))
            rows.append(StatRowGroup.Row(title: "Mes más barato", value: Self.describe(extremes.lowest)))
        }
        return rows
    }

    private static func describe(_ point: MonthlyPoint) -> String {
        let month = point.month.formatted(.dateTime.month(.wide)).capitalized
        return "\(month) · \(Money(amount: point.expenses, currency: point.currency).formatted())"
    }

    // MARK: - Comparaciones

    @ViewBuilder
    private func comparisonsSection(_ currency: Currency) -> some View {
        let previousMonth = model.comparisonWithPreviousMonth?.expenseDelta(in: currency)
        let lastYear = model.comparisonWithSameMonthLastYear?.expenseDelta(in: currency)

        if previousMonth != nil || lastYear != nil {
            YearComparisonCard(
                title: comparisonTitle,
                previousMonth: previousMonth,
                sameMonthLastYear: lastYear)
        }
    }

    private var comparisonTitle: String {
        guard let month = model.latestActiveMonth else { return "Comparación" }
        return month.formatted(.dateTime.month(.wide)).capitalized
    }

    // MARK: - Desgloses

    private func categoryTotals(_ currency: Currency) -> [CategoryTotal] {
        model.statistics.period.categoryTotals(in: currency)
    }

    private func breakdownSection(
        _ title: String,
        totals: [CategoryTotal],
        onSelect: @escaping (String) -> Void) -> some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                SectionCaption(title)
                CategoryBreakdownChart(totals: totals, onSelect: onSelect)
            }
        }
    }

    /// De dónde vino el dinero (ADR-0040). Bloque propio y no una barra más
    /// del desglose de gastos: son catálogos distintos, y un ingreso al lado de
    /// un gasto en la misma gráfica se leería como si compitieran.
    ///
    /// Sin drill-down: `CategoryDetailModel` filtra gastos por categoría, no
    /// ingresos, y pintar filas tocables prometería una pantalla que no existe.
    @ViewBuilder
    private func incomeSection(_ currency: Currency) -> some View {
        let totals = model.statistics.period.incomeCategoryTotals(in: currency)
        if !totals.isEmpty {
            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    SectionCaption("De dónde vino el dinero")
                    StatRowGroup(totals.map { total in
                        StatRowGroup.Row(
                            title: total.category.capitalized,
                            value: Money(amount: total.amount, currency: total.currency).formatted())
                    })
                }
            }
        }
    }

    // MARK: - La cola larga

    /// Lo que se consulta de vez en cuando, plegado.
    ///
    /// Subcategorías, forma de pago, gastos hormiga y días con movimiento son
    /// datos buenos que nadie mira cada vez que abre el año. Sueltos ocupaban
    /// cuatro tarjetas idénticas y empujaban lo importante fuera de pantalla.
    @ViewBuilder
    private func detailSection(_ currency: Currency) -> some View {
        let subcategories = Array(model.statistics.period.subcategoryTotals(in: currency).prefix(5))
        let paymentMethods = model.statistics.period.paymentMethodTotals(in: currency)
        let ants = model.statistics.antExpenses(in: currency)
        let consistency = model.statistics.captureConsistency

        if !subcategories.isEmpty || !paymentMethods.isEmpty || !ants.isEmpty || consistency.daysWithActivity > 0 {
            LanaCard {
                DisclosureGroup(isExpanded: $isDetailExpanded) {
                    VStack(alignment: .leading, spacing: Space.md.rawValue) {
                        if !subcategories.isEmpty {
                            detailBlock("En qué específicamente", rows: subcategories.map(Self.row(for:)))
                        }
                        if !paymentMethods.isEmpty {
                            detailBlock("Por forma de pago", rows: paymentMethods.map(Self.row(for:)))
                        }
                        if !ants.isEmpty {
                            detailBlock("Chico pero seguido", rows: ants.map { group in
                                StatRowGroup.Row(
                                    title: "\(group.label.capitalized) · \(group.count) veces",
                                    value: Money(amount: group.total, currency: group.currency).formatted())
                            })
                        }
                        if consistency.daysWithActivity > 0 {
                            detailBlock("Días con movimiento", rows: Self.rows(for: consistency))
                        }
                    }
                    .padding(.top, Space.sm.rawValue)
                } label: {
                    SectionCaption("Más detalle")
                }
                .tint(lana.highlight)
            }
        }
    }

    private func detailBlock(_ title: String, rows: [StatRowGroup.Row]) -> some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            SectionCaption(title)
            StatRowGroup(rows)
        }
    }

    private static func row(for total: CategoryTotal) -> StatRowGroup.Row {
        StatRowGroup.Row(
            title: total.category.capitalized,
            value: Money(amount: total.amount, currency: total.currency).formatted())
    }

    /// "Días con movimiento", no "racha de captura": el dato sale de la fecha
    /// del gasto, no de cuándo se registró (ver `CaptureConsistency`).
    private static func rows(for consistency: CaptureConsistency) -> [StatRowGroup.Row] {
        var rows = [
            StatRowGroup.Row(
                title: "Días registrados",
                value: "\(consistency.daysWithActivity) de \(consistency.daysElapsed)"),
            StatRowGroup.Row(title: "Racha más larga", value: "\(consistency.longestStreak) días")
        ]
        if consistency.currentStreak > 0 {
            rows.append(StatRowGroup.Row(title: "Racha actual", value: "\(consistency.currentStreak) días"))
        }
        return rows
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            YearView(model: YearModel(
                store: InMemoryExpenseStore(),
                cardStore: InMemoryCardStore(),
                sharedListStore: InMemorySharedListStore()))
        }
        .lanaTheme(theme)
    }
}

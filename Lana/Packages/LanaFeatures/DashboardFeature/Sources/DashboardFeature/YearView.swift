import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// El año completo (rediseño, sección 09): estadísticas puras, sin IA de por
/// medio — funciona igual en un dispositivo sin Apple Intelligence.
///
/// Se empuja desde Mes, en **su** `NavigationStack`, así que no arma uno
/// propio: avisa hacia arriba con callbacks a dónde quiere navegar.
public struct YearView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: YearModel

    private let selectedMonth: Date?
    private let onSelectMonth: (Date) -> Void
    private let onSelectCategory: (String) -> Void
    private let onOpenDetail: (Currency) -> Void

    /// Cuántas categorías se ven antes de "Ver las N categorías".
    private static var collapsedCategoryCount: Int {
        4
    }

    @State private var showsAllCategories = false

    /// - Parameters:
    ///   - selectedMonth: el mes que se está viendo en Mes, para marcarlo entre
    ///     las doce barras.
    ///   - onOpenDetail: "Más detalle" — subcategorías, gastos hormiga, rachas.
    public init(
        model: YearModel,
        selectedMonth: Date? = nil,
        onSelectMonth: @escaping (Date) -> Void = { _ in },
        onSelectCategory: @escaping (String) -> Void = { _ in },
        onOpenDetail: @escaping (Currency) -> Void = { _ in }) {
        self.model = model
        self.selectedMonth = selectedMonth
        self.onSelectMonth = onSelectMonth
        self.onSelectCategory = onSelectCategory
        self.onOpenDetail = onOpenDetail
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                YearSelector(
                    year: model.year,
                    onPrevious: { Task { await model.goToPreviousYear() } },
                    onNext: { Task { await model.goToNextYear() } })
                    .padding(.bottom, Space.p26.rawValue)

                if model.statistics.currencies.isEmpty {
                    // Suprimido mientras carga: si no, parpadea "en blanco"
                    // antes de que lleguen los datos.
                    if !model.isLoading {
                        EmptyStateView(
                            systemImage: "calendar",
                            title: "\(model.year) está en blanco",
                            message: "Empieza a registrar y aquí verás el año completo.")
                    }
                } else {
                    ForEach(model.statistics.currencies, id: \.rawValue) { currency in
                        currencyBlock(currency)
                    }
                }
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p14.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle("El año")
        .lanaInlineNavigationTitle()
        .task { await model.onAppear() }
        .refreshable { await model.onAppear() }
    }

    @ViewBuilder
    private func currencyBlock(_ currency: Currency) -> some View {
        // Con una sola moneda —el caso normal— el encabezado sobra. Con dos,
        // sin él no se ve dónde termina una y empieza la otra.
        if model.statistics.currencies.count > 1 {
            SectionHeader(currency.rawValue, style: .minor)
                .padding(.bottom, Space.p12.rawValue)
        }

        totalSection(currency)
            .padding(.bottom, Space.p30.rawValue)

        MonthlyBarsChart(
            points: model.statistics.monthlyPoints(in: currency),
            selectedMonth: selectedMonth,
            onSelect: onSelectMonth)
            .padding(.bottom, Space.p28.rawValue)

        comparisonsTable(currency)
            .padding(.bottom, Space.p30.rawValue)

        categoriesSection(currency)

        incomeSection(currency)

        NavRow("Más detalle", subtitle: "Subcategorías, gastos hormiga, rachas") {
            onOpenDetail(currency)
        }
        .background(lana.surface, in: RoundedRectangle(cornerRadius: Radius.card.rawValue, style: .continuous))
        .padding(.bottom, Space.p28.rawValue)
    }

    // MARK: - Total

    /// Los tres datos en una frase, no en tres filas de tabla: "2 meses con
    /// movimiento" se elimina — era ruido.
    @ViewBuilder
    private func totalSection(_ currency: Currency) -> some View {
        if let total = model.statistics.period.total(in: currency) {
            VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                Text("Gastado en \(model.year)")
                    .lanaFont(.footnote)
                    .foregroundStyle(lana.ink50)
                Text(Money(amount: total.expenses, currency: currency).formatted())
                    .lanaFont(.screenAmount)
                    .foregroundStyle(lana.ink)
                    .contentTransition(.numericText())
                if let summary = incomeSummary(currency, total: total) {
                    Text(summary)
                        .lanaFont(.callout)
                        .foregroundStyle(lana.ink50)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func incomeSummary(_ currency: Currency, total: PeriodTotal) -> String? {
        guard total.income > 0 else { return nil }
        let income = Money(amount: total.income, currency: currency).formatted()
        guard let rate = model.statistics.period.savingsRate(in: currency), rate > 0 else {
            return "Ingresaste \(income)"
        }
        let percent = NSDecimalNumber(decimal: rate * 100).intValue
        return "Ingresaste \(income) · ahorraste el \(percent)%"
    }

    // MARK: - Comparaciones

    /// Los meses van en español y en minúscula; la flecha va pegada al número.
    /// Bajar el gasto se pinta en `positive`; subirlo, en tinta normal — es un
    /// dato, no una alerta.
    @ViewBuilder
    private func comparisonsTable(_ currency: Currency) -> some View {
        let rows = comparisonRows(currency)
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: Space.p10.rawValue) {
                        Text(row.label)
                            .lanaFont(.bodyEmphasis)
                            .fontWeight(.regular)
                            .foregroundStyle(lana.ink70)
                        Spacer(minLength: Space.sm.rawValue)
                        Text(row.value)
                            .lanaFont(.rowAmountStrong)
                            .foregroundStyle(row.isPositive ? lana.positive : lana.ink)
                    }
                    .padding(.vertical, Space.p14.rawValue)
                    .accessibilityElement(children: .combine)
                    if index < rows.count - 1 {
                        HairlineDivider(strong: true)
                    }
                }
            }
        }
    }

    private struct ComparisonRow: Identifiable {
        let id: String
        let label: String
        let value: String
        let isPositive: Bool
    }

    private func comparisonRows(_ currency: Currency) -> [ComparisonRow] {
        var rows: [ComparisonRow] = []
        if let average = model.statistics.monthlyAverage(in: currency) {
            rows.append(ComparisonRow(
                id: "promedio",
                label: "Promedio mensual",
                value: Money(amount: average, currency: currency).formatted(),
                isPositive: false))
        }
        if let extremes = model.statistics.extremes(in: currency) {
            rows.append(ComparisonRow(
                id: "caro",
                label: "Mes más caro",
                value: Self.describe(extremes.highest),
                isPositive: false))
            rows.append(ComparisonRow(
                id: "barato",
                label: "Mes más barato",
                value: Self.describe(extremes.lowest),
                isPositive: false))
        }
        if let delta = model.comparisonWithPreviousMonth?.expenseDelta(in: currency),
           let relative = delta.relative,
           let month = model.latestActiveMonth {
            let percent = abs(NSDecimalNumber(decimal: relative * 100).intValue)
            let arrow = delta.direction == .down ? "↓" : "↑"
            rows.append(ComparisonRow(
                id: "contraMesAnterior",
                label: "\(LanaDateFormat.monthName(month)) vs el mes anterior",
                value: delta.direction == .unchanged ? "igual" : "\(arrow) \(percent)%",
                isPositive: delta.direction == .down))
        }
        return rows
    }

    private static func describe(_ point: MonthlyPoint) -> String {
        let month = LanaDateFormat.monthNameLowercased(point.month)
        return "\(month) · \(Money(amount: point.expenses, currency: point.currency).formatted())"
    }

    // MARK: - Desgloses

    @ViewBuilder
    private func categoriesSection(_ currency: Currency) -> some View {
        let totals = model.statistics.period.categoryTotals(in: currency)
        if !totals.isEmpty {
            SectionHeader("En qué se fue el año")
                .padding(.bottom, Space.md.rawValue)

            let visible = showsAllCategories ? totals : Array(totals.prefix(Self.collapsedCategoryCount))
            RankedBarList(items: visible.map(Self.rankedItem)) { item in
                onSelectCategory(item.id)
            }

            if totals.count > Self.collapsedCategoryCount {
                Button(showsAllCategories ? "Ver menos" : "Ver las \(totals.count) categorías") {
                    withAnimation(.easeInOut(duration: 0.25)) { showsAllCategories.toggle() }
                }
                .lanaFont(.detail)
                .foregroundStyle(lana.accent)
                .buttonStyle(.plain)
                .frame(minHeight: LanaMetrics.minTouchTarget)
                .padding(.top, Space.xs.rawValue)
            }

            Spacer()
                .frame(height: Space.p28.rawValue)
        }
    }

    static func rankedItem(_ total: CategoryTotal) -> RankedBarList.Item {
        RankedBarList.Item(
            id: total.category,
            title: DashboardModel.categoryDisplayName(total.category),
            amountText: Money(amount: total.amount, currency: total.currency).formatted(),
            value: NSDecimalNumber(decimal: total.amount).doubleValue)
    }

    /// De dónde vino el dinero (ADR-0040). Bloque propio y no una barra más del
    /// desglose de gastos: son catálogos distintos, y juntarlos se leería como
    /// si compitieran.
    @ViewBuilder
    private func incomeSection(_ currency: Currency) -> some View {
        let totals = model.statistics.period.incomeCategoryTotals(in: currency)
        if !totals.isEmpty {
            SectionHeader("De dónde vino el dinero")
                .padding(.bottom, Space.p12.rawValue)
            LanaCard(padding: nil) {
                VStack(spacing: 0) {
                    ForEach(Array(totals.enumerated()), id: \.element.id) { index, total in
                        HStack {
                            Text(total.category.prefix(1).uppercased() + total.category.dropFirst())
                                .lanaFont(.bodyEmphasis)
                                .fontWeight(.regular)
                                .foregroundStyle(lana.ink)
                            Spacer(minLength: Space.sm.rawValue)
                            Text(Money(amount: total.amount, currency: total.currency).formatted())
                                .lanaFont(.rowTitle)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(lana.positive)
                        }
                        .padding(Space.md.rawValue)
                        .accessibilityElement(children: .combine)
                        if index < totals.count - 1 {
                            HairlineDivider()
                        }
                    }
                }
            }
            .padding(.bottom, Space.p22.rawValue)
        }
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

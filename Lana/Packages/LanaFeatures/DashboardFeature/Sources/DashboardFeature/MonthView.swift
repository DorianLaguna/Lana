import LanaCore
import LanaDesign
import SwiftUI

/// A dónde se navega desde Mes.
private enum MonthDestination: Hashable {
    case category(String)
    case paymentMethods
    case paymentMethod(String)
    case recurring
    case year
    // Los drill-downs desde el año derivan de `YearModel`, no del mes: mismo
    // `String` en el path, distinto origen.
    case yearCategory(String)
    case yearPaymentMethod(String)
    /// "Más detalle" del año, por moneda — el `String` es su código ISO.
    case yearDetail(String)
}

/// Mes: todo el análisis del mes — en qué se fue, con qué se pagó, qué es
/// recurrente, y los accesos a El año y al Análisis (rediseño, sección 03).
/// Hoy responde; Mes explica. Sin lógica propia.
public struct MonthView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: DashboardModel
    @Bindable private var recurringItemsModel: RecurringItemsModel
    /// Se arma arriba y no dentro del destino: SwiftUI reconstruye el destino
    /// en cada redibujo y se perdería el año al que ya se navegó.
    @Bindable private var yearModel: YearModel
    @State private var path: [MonthDestination] = []
    @State private var editExpenseModel: EditExpenseModel?
    @State private var addRecurringItemModel: AddRecurringItemModel?
    @State private var showsAllCategories = false
    private let onRefresh: () async -> Void
    private let onOpenInsights: () -> Void
    private let onExpenseChanged: () -> Void
    /// `false` cuando Apple Intelligence no está disponible: la fila del
    /// Análisis se apaga y explica por qué. Lo resuelve la app, que es quien
    /// conoce `InsightsFeature`.
    private let isInsightsAvailable: Bool

    /// Cuántas categorías se ven antes de "Ver las N categorías".
    private static var collapsedCategoryCount: Int {
        5
    }

    /// - Parameters:
    ///   - onRefresh: el refresco completo (`DashboardRefresh`).
    ///   - onOpenInsights: el Análisis vive en `InsightsFeature`; la app lo
    ///     presenta.
    ///   - onExpenseChanged: se editó o borró un movimiento desde aquí.
    public init(
        model: DashboardModel,
        recurringItemsModel: RecurringItemsModel,
        yearModel: YearModel,
        onRefresh: @escaping () async -> Void = {},
        onOpenInsights: @escaping () -> Void = {},
        onExpenseChanged: @escaping () -> Void = {},
        isInsightsAvailable: Bool = true) {
        self.model = model
        self.recurringItemsModel = recurringItemsModel
        self.yearModel = yearModel
        self.onRefresh = onRefresh
        self.onOpenInsights = onOpenInsights
        self.onExpenseChanged = onExpenseChanged
        self.isInsightsAvailable = isInsightsAvailable
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonthSelector(
                        label: LanaDateFormat.monthYear(model.month),
                        onPrevious: { Task { await model.goToPreviousMonth() } },
                        onNext: { Task { await model.goToNextMonth() } })
                        .padding(.bottom, Space.p28.rawValue)

                    if model.expenses.isEmpty, !model.isLoading {
                        EmptyStateView(
                            systemImage: "chart.bar",
                            title: "Sin movimientos en \(LanaDateFormat.monthNameLowercased(model.month))",
                            message: "Cuando registres algo, aquí verás en qué se fue.",
                            actionTitle: "Ver otro mes",
                            action: { Task { await model.goToPreviousMonth() } })
                            .padding(.bottom, Space.p28.rawValue)
                    } else {
                        totalsSection
                        DailySpendingSection(model: model) { expense in
                            editExpenseModel = model.makeEditExpenseModel(for: expense)
                        }
                        categoriesSection
                    }

                    accessCard
                        .padding(.bottom, Space.p28.rawValue)

                    MonthMovementsList(model: model) { expense in
                        editExpenseModel = model.makeEditExpenseModel(for: expense)
                    }
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.sm.rawValue)
                .tabBarClearance()
            }
            .background(lana.bg)
            .lanaHidesNavigationBar()
            .refreshable { await onRefresh() }
            .task { await yearModel.onAppear() }
            .navigationDestination(for: MonthDestination.self, destination: destination)
            .sheet(item: $editExpenseModel) { editModel in
                EditExpenseView(model: editModel, onDone: {
                    editExpenseModel = nil
                    onExpenseChanged()
                })
            }
            .sheet(item: $addRecurringItemModel) { addModel in
                AddRecurringItemView(model: addModel, onDone: {
                    addRecurringItemModel = nil
                    Task { await onRefresh() }
                })
            }
        }
    }

    // MARK: - Gastado / Ingresos

    private var totalsSection: some View {
        // Las mismas cifras que Hoy: la tarjeta por su corte y los sueldos que
        // faltan por caer (ADR-0060).
        ForEach(model.budgetTotals()) { total in
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Space.lg.rawValue) {
                    stat("Gastado", Money(amount: total.expenses, currency: total.currency), color: lana.ink)
                    if total.income > 0 {
                        stat("Ingresos", Money(amount: total.income, currency: total.currency), color: lana.positive)
                    }
                }
                .padding(.bottom, Space.md.rawValue)

                if let fraction = DashboardModel.spentFraction(of: total) {
                    ProgressTrack(fraction: fraction, height: LanaMetrics.barThick, fill: .accentGradient)
                }

                MonthTotalsNotes(notes: model.monthTotalsNotes(in: total.currency))
            }
            .padding(.bottom, Space.xl.rawValue)
            .contentShape(Rectangle())
            // El swipe horizontal sobre las cifras también cambia de mes.
            .gesture(DragGesture(minimumDistance: Space.p30.rawValue).onEnded { value in
                if value.translation.width < -Space.xxl.rawValue {
                    Task { await model.goToNextMonth() }
                } else if value.translation.width > Space.xxl.rawValue {
                    Task { await model.goToPreviousMonth() }
                }
            })
        }
    }

    private func stat(_ label: String, _ money: Money, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            Text(label)
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink50)
            Text(MoneyDisplay.whole(money))
                .lanaFont(.blockAmount)
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - En qué se fue

    @ViewBuilder
    private var categoriesSection: some View {
        let totals = model.primaryCategoryTotals
        if !totals.isEmpty {
            SectionHeader("En qué se fue")
                .padding(.bottom, Space.md.rawValue)

            let visible = showsAllCategories ? totals : Array(totals.prefix(Self.collapsedCategoryCount))
            RankedBarList(items: visible.map(rankedItem)) { item in
                path.append(.category(item.id))
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
                .frame(height: Space.p30.rawValue)
        }
    }

    private func rankedItem(_ total: CategoryTotal) -> RankedBarList.Item {
        RankedBarList.Item(
            id: total.category,
            title: DashboardModel.categoryDisplayName(total.category),
            amountText: MoneyDisplay.whole(Money(amount: total.amount, currency: total.currency)),
            value: NSDecimalNumber(decimal: total.amount).doubleValue)
    }

    // MARK: - Accesos

    /// Cada fila lleva un dato real a la derecha: dice qué hay dentro y ya
    /// adelanta la respuesta. Reemplaza a los tres iconos sin nombre de la
    /// barra superior del Dashboard.
    private var accessCard: some View {
        LanaCard(padding: nil) {
            VStack(spacing: 0) {
                NavRow("Formas de pago", value: model.paymentMixSummary) {
                    path.append(.paymentMethods)
                }
                HairlineDivider()
                NavRow("Recurrentes", value: recurringValue, valueTone: recurringTone) {
                    path.append(.recurring)
                }
                HairlineDivider()
                // Sin Apple Intelligence la fila se apaga y dice por qué, en
                // vez de desaparecer: esconderla dejaría al usuario sin saber
                // que existe (rediseño, sección 14).
                NavRow(
                    "Análisis con Lana",
                    subtitle: isInsightsAvailable ? nil : "Necesita Apple Intelligence",
                    subtitleTone: .disabled,
                    value: isInsightsAvailable ? model.savingsSummary : nil,
                    isDimmed: !isInsightsAvailable,
                    action: onOpenInsights)
                HairlineDivider()
                NavRow("El año", value: yearValue) {
                    path.append(.year)
                }
            }
        }
    }

    private var recurringValue: String? {
        let pending = recurringItemsModel.pendingCount()
        if pending > 0 {
            return pending == 1 ? "1 pendiente" : "\(pending) pendientes"
        }
        let count = recurringItemsModel.items.count
        guard count > 0 else { return nil }
        return count == 1 ? "1 fijo" : "\(count) fijos"
    }

    private var recurringTone: LanaTone {
        recurringItemsModel.pendingCount() > 0 ? .attention : .muted
    }

    private var yearValue: String? {
        guard let currency = model.primaryCurrency ?? yearModel.statistics.currencies.first,
              let total = yearModel.statistics.period.total(in: currency),
              total.expenses > 0 else { return nil }
        return "\(MoneyDisplay.whole(Money(amount: total.expenses, currency: currency))) en \(yearModel.year)"
    }

    // MARK: - Destinos

    @ViewBuilder
    private func destination(_ destination: MonthDestination) -> some View {
        switch destination {
        case let .category(category):
            CategoryDetailView(model: model.makeCategoryDetailModel(for: category)) { expense in
                editExpenseModel = model.makeEditExpenseModel(for: expense)
            }
        case .paymentMethods:
            PaymentMethodsView(model: model) { label in
                path.append(.paymentMethod(label))
            }
        case let .paymentMethod(label):
            PaymentMethodDetailView(model: model.makePaymentMethodDetailModel(for: label)) { expense in
                editExpenseModel = model.makeEditExpenseModel(for: expense)
            }
        case .recurring:
            RecurringItemsScreen(
                model: recurringItemsModel,
                onAdd: { addRecurringItemModel = recurringItemsModel.makeAddModel() },
                onEdit: { addRecurringItemModel = recurringItemsModel.makeAddModel(editing: $0) },
                onChanged: onRefresh)
        case .year:
            YearView(
                model: yearModel,
                selectedMonth: model.month,
                // Tocar un mes regresa a Mes ya posado en él.
                onSelectMonth: { month in
                    path.removeAll()
                    Task { await model.goToMonth(month) }
                },
                onSelectCategory: { path.append(.yearCategory($0)) },
                onOpenDetail: { path.append(.yearDetail($0.rawValue)) })
        case let .yearCategory(category):
            CategoryDetailView(model: yearModel.makeCategoryDetailModel(for: category)) { expense in
                editExpenseModel = model.makeEditExpenseModel(for: expense)
            }
        case let .yearPaymentMethod(label):
            PaymentMethodDetailView(model: yearModel.makePaymentMethodDetailModel(for: label)) { expense in
                editExpenseModel = model.makeEditExpenseModel(for: expense)
            }
        case let .yearDetail(currencyCode):
            YearDetailView(statistics: yearModel.statistics, currency: Currency(rawValue: currencyCode))
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        MonthView(
            model: DashboardModel(
                store: InMemoryExpenseStore(),
                vocabularyStore: InMemoryCorrectionVocabularyStore(),
                cardStore: InMemoryCardStore(),
                sharedListStore: InMemorySharedListStore()),
            recurringItemsModel: RecurringItemsModel(
                recurringItemStore: InMemoryRecurringItemStore(),
                store: InMemoryExpenseStore(),
                cardStore: InMemoryCardStore()),
            yearModel: YearModel(
                store: InMemoryExpenseStore(),
                cardStore: InMemoryCardStore(),
                sharedListStore: InMemorySharedListStore()))
            .lanaTheme(theme)
    }
}

/// Lo que explica la cifra de Mes frente a su lista: los sueldos que ya cuenta
/// y lo que movió el corte de las tarjetas (ADR-0060).
private struct MonthTotalsNotes: View {
    @Environment(\.lana) private var lana
    let notes: [String]

    var body: some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                ForEach(notes, id: \.self) { note in
                    Text(note)
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, Space.p10.rawValue)
        }
    }
}

/// La lista de Mes: lo del mes por fecha, con "Para octubre" en lo que ya le
/// cuenta al siguiente, y al final lo del mes anterior que entró en este
/// corte (ADR-0060).
private struct MonthMovementsList: View {
    let model: DashboardModel
    let onSelect: (Expense) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Space.p20.rawValue) {
            ForEach(model.daySections) { section in
                daySection(section, header: LanaDateFormat.dayHeader(section.day))
            }
            let carriedIn = model.carriedInSections
            if !carriedIn.isEmpty {
                SectionHeader(carriedInTitle)
                    .padding(.top, Space.p10.rawValue)
                ForEach(carriedIn) { section in
                    daySection(section, header: LanaDateFormat.dayHeader(section.day))
                }
            }
        }
    }

    /// "De septiembre, en este corte".
    private var carriedInTitle: String {
        let previous = model.calendar.date(byAdding: .month, value: -1, to: model.month) ?? model.month
        return "De \(LanaDateFormat.monthNameLowercased(previous)), en este corte"
    }

    private func daySection(_ section: DaySection, header: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(header)
            MovementRows(
                expenses: section.items,
                source: model,
                highlightedIDs: model.highlightedExpenseIDs,
                deferredLabel: model.deferredLabel(for:),
                onSelect: onSelect)
        }
    }
}

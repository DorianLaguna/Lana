import LanaCore
import LanaDesign
import SwiftUI

/// A dónde puede navegar el Dashboard desde sus dos gráficas — categoría y
/// forma de pago comparten el mismo `CategoryBreakdownChart`, pero cada una
/// lleva a un drill-down distinto, así que un solo `[String]` en el path no
/// alcanza para distinguirlos (antes, tocar una rebanada de "Por forma de
/// pago" no hacía nada — el callback de tap ni siquiera existía).
private enum DashboardDestination: Hashable {
    case category(String)
    case paymentMethod(String)
    /// La vista anual (estadísticas puras, sin IA).
    case year
    // Los drill-downs desde el año son los mismos que los del mes, pero
    // derivan de `YearModel` en vez de `DashboardModel` — mismo `String` en el
    // path, distinto origen, así que necesitan su propio caso o entrarían al
    // detalle del mes con el título del año.
    case yearCategory(String)
    case yearPaymentMethod(String)
}

/// El dashboard mensual — ahora también el hogar de la captura (Fase 6.5),
/// aunque el micrófono en sí vive en la barra de tabs (`ContentView`), no
/// aquí. Sin lógica propia — refleja `DashboardModel`/`RecurringItemsModel`
/// (Docs/ARCHITECTURE.md).
public struct DashboardView: View {
    @Environment(\.lana) private var lana
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var model: DashboardModel
    @Bindable private var recurringItemsModel: RecurringItemsModel
    @Bindable private var upcomingCardPaymentsModel: UpcomingCardPaymentsModel
    /// La vista anual se arma aquí arriba, como los demás modelos, y no dentro
    /// del `navigationDestination`: SwiftUI reconstruye el destino en cada
    /// redibujo, y con él se perdería el año al que el usuario ya había
    /// navegado (y se recargaría el store cada vez).
    @Bindable private var yearModel: YearModel
    @State private var path: [DashboardDestination] = []
    @State private var addRecurringItemModel: AddRecurringItemModel?
    @State private var editExpenseModel: EditExpenseModel?
    /// `SharedFeature` no puede llamarse desde aquí (las features no se
    /// importan entre sí) — un gasto editado o borrado desde este Dashboard
    /// puede ser compartido, y `ContentView` (que sí conoce ambas features)
    /// usa este aviso para refrescar el detalle de lista compartida que
    /// esté en pantalla. Sin este aviso, el saldo en "Compartido" se
    /// quedaba con la cifra vieja hasta salir y volver a entrar a esa
    /// lista — el bug real detrás de "ya no debería haber deuda".
    private let onExpenseChanged: () -> Void
    /// El Análisis con IA vive en `InsightsFeature`, que esta feature no puede
    /// importar — `MainTabView`, que sí conoce las dos, lo presenta. Mismo
    /// patrón que `onExpenseChanged`.
    private let onOpenInsights: () -> Void

    public init(
        model: DashboardModel,
        recurringItemsModel: RecurringItemsModel,
        upcomingCardPaymentsModel: UpcomingCardPaymentsModel,
        yearModel: YearModel,
        onExpenseChanged: @escaping () -> Void = {},
        onOpenInsights: @escaping () -> Void = {}) {
        self.model = model
        self.recurringItemsModel = recurringItemsModel
        self.upcomingCardPaymentsModel = upcomingCardPaymentsModel
        self.yearModel = yearModel
        self.onExpenseChanged = onExpenseChanged
        self.onOpenInsights = onOpenInsights
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Space.md.rawValue) {
                    MonthSelector(
                        month: model.month,
                        onPrevious: { Task { await model.goToPreviousMonth() } },
                        onNext: { Task { await model.goToNextMonth() } })

                    monthSummary

                    RecurringItemsSection(
                        items: recurringItemsModel.items,
                        registrations: recurringItemsModel.registrations,
                        onAdd: { addRecurringItemModel = recurringItemsModel.makeAddModel() },
                        onEdit: { item in addRecurringItemModel = recurringItemsModel.makeAddModel(editing: item) },
                        onRegister: { item in
                            Task {
                                try? await recurringItemsModel.register(item)
                                await recurringItemsModel.onAppear()
                                await model.onAppear()
                            }
                        },
                        onDelete: { item in Task { try? await recurringItemsModel.delete(item) } })

                    UpcomingCardPaymentsSection(
                        dueThisPayPeriod: upcomingCardPaymentsModel.dueThisPayPeriod,
                        totalsByCurrency: upcomingCardPaymentsModel.totalsByCurrency)

                    ReviewTrayView(
                        sections: [DaySection(day: Date(), items: model.needsReviewItems)]
                            .filter { !$0.items.isEmpty }) { expense in
                        editExpenseModel = model.makeEditExpenseModel(for: expense)
                    }

                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Por categoría")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.textSecondary)
                            CategoryBreakdownChart(totals: model.categoryTotals) { category in
                                path.append(.category(category))
                            }
                        }
                    }

                    if !model.paymentMethodTotals.isEmpty {
                        LanaCard {
                            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                                Text("Por forma de pago")
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.textSecondary)
                                CategoryBreakdownChart(totals: model.paymentMethodTotals) { label in
                                    path.append(.paymentMethod(label))
                                }
                            }
                        }
                    }

                    DaySectionListView(
                        sections: model.daySections,
                        onSelect: { expense in editExpenseModel = model.makeEditExpenseModel(for: expense) },
                        viewerIdentities: model.viewerIdentities)
                }
                .padding(Space.md.rawValue)
                .floatingMicClearance()
            }
            .background(lana.surface)
            .navigationTitle("Dashboard")
            // El registro a mano (ADR-0035), a propósito discreto: el
            // micrófono flotante sigue siendo el camino principal y el
            // centro visual de la app. Reusa la misma hoja y el mismo
            // `onDone` que editar — es el mismo formulario, en modo crear.
            .toolbar {
                // Las dos lecturas (el año y el análisis) van juntas y a la
                // izquierda del `+`, que es la única acción que escribe algo.
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        path.append(.year)
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("Ver el año")

                    Button(action: onOpenInsights) {
                        Image(systemName: "sparkles")
                    }
                    .accessibilityLabel("Análisis con IA")

                    Button {
                        editExpenseModel = model.makeNewExpenseModel()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Agregar a mano")
                }
            }
            .navigationDestination(for: DashboardDestination.self) { destination in
                switch destination {
                case let .category(category):
                    CategoryDetailView(model: model.makeCategoryDetailModel(for: category)) { expense in
                        editExpenseModel = model.makeEditExpenseModel(for: expense)
                    }
                case let .paymentMethod(label):
                    PaymentMethodDetailView(model: model.makePaymentMethodDetailModel(for: label)) { expense in
                        editExpenseModel = model.makeEditExpenseModel(for: expense)
                    }
                case .year:
                    YearView(
                        model: yearModel,
                        // Tocar un mes regresa al Dashboard ya posado en él:
                        // un solo toque, sin pantalla intermedia.
                        onSelectMonth: { month in
                            path.removeAll()
                            Task { await model.goToMonth(month) }
                        },
                        onSelectCategory: { path.append(.yearCategory($0)) },
                        onSelectPaymentMethod: { path.append(.yearPaymentMethod($0)) })
                case let .yearCategory(category):
                    CategoryDetailView(model: yearModel.makeCategoryDetailModel(for: category)) { expense in
                        editExpenseModel = model.makeEditExpenseModel(for: expense)
                    }
                case let .yearPaymentMethod(label):
                    PaymentMethodDetailView(model: yearModel.makePaymentMethodDetailModel(for: label)) { expense in
                        editExpenseModel = model.makeEditExpenseModel(for: expense)
                    }
                }
            }
            .sheet(item: $addRecurringItemModel) { addModel in
                AddRecurringItemView(model: addModel, onDone: {
                    addRecurringItemModel = nil
                    Task {
                        await recurringItemsModel.onAppear()
                        await model.onAppear()
                    }
                })
            }
            .sheet(item: $editExpenseModel) { editModel in
                EditExpenseView(model: editModel, onDone: {
                    editExpenseModel = nil
                    // `CategoryDetailModel`/`PaymentMethodDetailModel` (si
                    // hay uno empujado) derivan sus gastos de `model` en
                    // vivo — no hace falta refrescarlos aparte. La vista
                    // anual sí: tiene su propia carga de veinticuatro meses,
                    // y sin esto un gasto editado desde el drill-down del año
                    // dejaría las barras con la cifra vieja.
                    Task {
                        await model.onAppear()
                        await yearModel.refreshIfLoaded()
                        // Borrar el movimiento de un recurrente lo deja
                        // pendiente otra vez (ADR-0042) — sin recargar, la
                        // fila seguiría diciendo "Registrado".
                        await recurringItemsModel.onAppear()
                    }
                    onExpenseChanged()
                })
            }
        }
        .task { await refresh() }
        .refreshable { await refresh() }
        // Con la app viva en segundo plano desde antes del día de pago, el
        // sueldo no se registraba hasta matarla o jalar para refrescar.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refresh() }
        }
    }

    /// Primero los recurrentes vencidos (puede crear gastos nuevos), luego el
    /// mes — si no, el mes se carga sin lo que se acaba de registrar
    /// automáticamente.
    private func refresh() async {
        await recurringItemsModel.onAppear()
        await recurringItemsModel.registerDueItems()
        await model.onAppear()
        await upcomingCardPaymentsModel.onAppear()
    }

    /// Un solo bloque por moneda — antes eran dos: las cajas de
    /// Gastado/Ingresos en su propio renglón y, debajo, la dona en otra
    /// tarjeta aparte. Quedaban desconectadas (mismo dato, dos veces, dos
    /// cajas grises distintas) y dejaban el tope del Dashboard con esa
    /// sensación de "vacío sin usar" que sí tiene Tarjetas gracias a su
    /// botón de agregar — aquí no hay un botón que llenar ese espacio, pero
    /// si el resumen es una sola pieza fuerte, no hace falta.
    @ViewBuilder
    private var monthSummary: some View {
        if model.monthTotals.isEmpty {
            LanaCard {
                Text("Sin movimientos este mes")
                    .lanaFont(.body)
                    .foregroundStyle(lana.textSecondary)
            }
        } else {
            ForEach(model.monthTotals) { total in
                LanaCard {
                    VStack(spacing: Space.md.rawValue) {
                        HStack(spacing: Space.sm.rawValue) {
                            statCard(
                                title: "Gastado",
                                amount: Money(amount: total.expenses, currency: total.currency).formatted(),
                                tint: lana.accent,
                                onTint: .white)
                            if total.income > 0 {
                                statCard(
                                    title: "Ingresos",
                                    amount: Money(amount: total.income, currency: total.currency).formatted(),
                                    tint: lana.positive.opacity(0.12),
                                    onTint: lana.positive)
                            }
                        }
                        // Solo con ingreso registrado — sin eso, "cuánto
                        // sobra" no tiene con qué compararse (mostrar $0
                        // disponible sería un dato falso, no su ausencia).
                        if total.income > 0 {
                            RemainingDonutChart(
                                categoryTotals: model.categoryTotals(in: total.currency),
                                income: total.income,
                                currency: total.currency)
                        }
                    }
                }
            }
        }
    }

    private func statCard(title: String, amount: String, tint: Color, onTint: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            Text(title)
                .lanaFont(.caption)
                .foregroundStyle(onTint.opacity(0.8))
            Text(amount)
                .lanaFont(.headline)
                .monospacedDigit()
                .foregroundStyle(onTint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md.rawValue)
        .background(tint, in: RoundedRectangle(cornerRadius: Space.sm.rawValue, style: .continuous))
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        DashboardView(
            model: DashboardModel(
                store: InMemoryExpenseStore(),
                vocabularyStore: InMemoryCorrectionVocabularyStore(),
                cardStore: InMemoryCardStore(),
                sharedListStore: InMemorySharedListStore()),
            recurringItemsModel: RecurringItemsModel(
                recurringItemStore: InMemoryRecurringItemStore(),
                store: InMemoryExpenseStore(),
                cardStore: InMemoryCardStore()),
            upcomingCardPaymentsModel: UpcomingCardPaymentsModel(
                cardStore: InMemoryCardStore(),
                cardPaymentStore: InMemoryCardPaymentStore()),
            yearModel: YearModel(
                store: InMemoryExpenseStore(),
                cardStore: InMemoryCardStore(),
                sharedListStore: InMemorySharedListStore()))
            .lanaTheme(theme)
    }
}

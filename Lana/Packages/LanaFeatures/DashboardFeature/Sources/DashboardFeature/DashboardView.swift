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
}

/// El dashboard mensual — ahora también el hogar de la captura (Fase 6.5),
/// aunque el micrófono en sí vive en la barra de tabs (`ContentView`), no
/// aquí. Sin lógica propia — refleja `DashboardModel`/`RecurringItemsModel`
/// (Docs/ARCHITECTURE.md).
public struct DashboardView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: DashboardModel
    @Bindable private var recurringItemsModel: RecurringItemsModel
    @Bindable private var upcomingCardPaymentsModel: UpcomingCardPaymentsModel
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

    public init(
        model: DashboardModel,
        recurringItemsModel: RecurringItemsModel,
        upcomingCardPaymentsModel: UpcomingCardPaymentsModel,
        onExpenseChanged: @escaping () -> Void = {}) {
        self.model = model
        self.recurringItemsModel = recurringItemsModel
        self.upcomingCardPaymentsModel = upcomingCardPaymentsModel
        self.onExpenseChanged = onExpenseChanged
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
                .padding(.bottom, Space.xxl.rawValue)
            }
            .background(lana.surface)
            .navigationTitle("Dashboard")
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
                    // vivo — no hace falta refrescarlos aparte.
                    Task { await model.onAppear() }
                    onExpenseChanged()
                })
            }
        }
        .task {
            // Primero los recurrentes vencidos (puede crear gastos nuevos),
            // luego el mes — si no, el mes se carga sin lo que se acaba de
            // registrar automáticamente.
            await recurringItemsModel.onAppear()
            await recurringItemsModel.registerDueItems()
            await model.onAppear()
            await upcomingCardPaymentsModel.onAppear()
        }
        .refreshable {
            await recurringItemsModel.onAppear()
            await recurringItemsModel.registerDueItems()
            await model.onAppear()
            await upcomingCardPaymentsModel.onAppear()
        }
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
                cardPaymentStore: InMemoryCardPaymentStore()))
            .lanaTheme(theme)
    }
}

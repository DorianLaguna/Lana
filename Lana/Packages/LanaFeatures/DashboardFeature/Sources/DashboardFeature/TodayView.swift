import LanaCore
import LanaDesign
import SwiftUI

/// A dónde se navega desde Hoy. La bandeja "Por revisar" no está aquí: es una
/// hoja de `EntryFeature`, que esta feature no puede importar, así que la
/// presenta la app.
private enum TodayDestination: Hashable {
    case settings
}

/// Hoy: responde una sola pregunta — cuánto me queda y cuánto puedo gastar
/// hoy (rediseño, sección 02; ADR-0045). Se lee en tres segundos; todo lo que
/// no ayude a eso vive en Mes. Sin lógica propia: refleja `DashboardModel` y
/// `UpcomingCardPaymentsModel`.
public struct TodayView<Settings: View>: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: DashboardModel
    @Bindable private var upcomingCardPaymentsModel: UpcomingCardPaymentsModel
    @State private var path: [TodayDestination] = []
    @State private var editExpenseModel: EditExpenseModel?
    private let scrollToTopTrigger: Int
    private let onRefresh: () async -> Void
    private let onOpenMonth: () -> Void
    private let onOpenCards: () -> Void
    private let onOpenReview: () -> Void
    private let onExpenseChanged: () -> Void
    private let settings: () -> Settings

    private static var topID: String {
        "today-top"
    }

    /// - Parameters:
    ///   - scrollToTopTrigger: cambia cada vez que se vuelve a Hoy; el scroll
    ///     regresa arriba.
    ///   - onRefresh: el refresco completo (`DashboardRefresh`), decidido por
    ///     la app.
    ///   - onOpenMonth: cambia a la pestaña Mes.
    ///   - onOpenCards: cambia a la pestaña Tarjetas.
    ///   - onOpenReview: abre la bandeja de lo que quedó por revisar.
    ///   - onExpenseChanged: se editó o borró un movimiento desde aquí.
    ///   - settings: Ajustes vive en otra feature; la app lo construye y Hoy
    ///     lo empuja desde el avatar.
    public init(
        model: DashboardModel,
        upcomingCardPaymentsModel: UpcomingCardPaymentsModel,
        scrollToTopTrigger: Int = 0,
        onRefresh: @escaping () async -> Void = {},
        onOpenMonth: @escaping () -> Void = {},
        onOpenCards: @escaping () -> Void = {},
        onOpenReview: @escaping () -> Void = {},
        onExpenseChanged: @escaping () -> Void = {},
        @ViewBuilder settings: @escaping () -> Settings) {
        self.model = model
        self.upcomingCardPaymentsModel = upcomingCardPaymentsModel
        self.scrollToTopTrigger = scrollToTopTrigger
        self.onRefresh = onRefresh
        self.onOpenMonth = onOpenMonth
        self.onOpenCards = onOpenCards
        self.onOpenReview = onOpenReview
        self.onExpenseChanged = onExpenseChanged
        self.settings = settings
    }

    public var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .id(Self.topID)
                            .padding(.bottom, Space.p34.rawValue)
                        if model.monthTotals.isEmpty {
                            emptyState
                        } else {
                            content
                        }
                    }
                    .padding(.horizontal, LanaMetrics.screenMargin)
                    .padding(.top, Space.sm.rawValue)
                    .tabBarClearance(.today)
                }
                .onChange(of: scrollToTopTrigger) {
                    withAnimation { proxy.scrollTo(Self.topID, anchor: .top) }
                }
            }
            .background(lana.bg)
            .lanaHidesNavigationBar()
            .refreshable { await onRefresh() }
            .navigationDestination(for: TodayDestination.self) { destination in
                switch destination {
                case .settings:
                    settings()
                }
            }
            .sheet(item: $editExpenseModel) { editModel in
                EditExpenseView(model: editModel, onDone: {
                    editExpenseModel = nil
                    onExpenseChanged()
                })
            }
        }
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
            Menu {
                ForEach(model.selectableMonths(), id: \.self) { month in
                    Button(LanaDateFormat.monthYear(month)) {
                        Task { await model.goToMonth(month) }
                    }
                }
            } label: {
                Text(LanaDateFormat.monthName(model.month))
                    .lanaFont(.screenTitle)
                    .foregroundStyle(lana.ink)
            }
            .accessibilityHint("Elegir otro mes")

            if let progress = model.dayProgress() {
                Text("día \(progress.day) de \(progress.daysInMonth)")
                    .lanaFont(.footnote)
                    .foregroundStyle(lana.ink42)
            }

            Spacer(minLength: Space.sm.rawValue)

            Button {
                path.append(.settings)
            } label: {
                Image(systemName: "person.fill")
                    .lanaFont(.caption2)
                    .foregroundStyle(lana.ink70)
                    .frame(width: LanaMetrics.avatarSmall, height: LanaMetrics.avatarSmall)
                    .background(lana.surface2, in: Circle())
                    .frame(width: LanaMetrics.minTouchTarget, height: LanaMetrics.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ajustes")
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        heroSection
            .padding(.bottom, Space.p28.rawValue)

        if let total = model.monthTotals.first, let pace = model.dailyPace(for: total) {
            DailyPaceCard(pace: pace)
                .padding(.bottom, Space.p10.rawValue)
        }

        let reviewCount = model.needsReviewItems.count
        if reviewCount > 0 {
            ReviewPromptRow(count: reviewCount, action: onOpenReview)
                .padding(.bottom, Space.p28.rawValue)
        } else {
            Spacer()
                .frame(height: Space.p18.rawValue)
        }

        if !upcomingCardPaymentsModel.dueThisPayPeriod.isEmpty {
            SectionHeader("Esta quincena")
                .padding(.bottom, Space.p12.rawValue)
            Button(action: onOpenCards) {
                FortnightCardsCard(
                    dues: upcomingCardPaymentsModel.dueThisPayPeriod,
                    totals: upcomingCardPaymentsModel.totalsByCurrency)
            }
            .buttonStyle(.plain)
            .padding(.bottom, Space.p28.rawValue)
        }

        if let recent = model.recentMovements() {
            SectionHeader(
                recent.isToday ? "Hoy" : LanaDateFormat.dayHeader(recent.day),
                actionTitle: "Ver el mes",
                action: onOpenMonth)
            MovementRows(
                expenses: recent.items,
                source: model,
                highlightedIDs: model.highlightedExpenseIDs) { expense in
                    editExpenseModel = model.makeEditExpenseModel(for: expense)
                }
        }
    }

    /// Con más de una moneda, una página por moneda — nunca se mezclan.
    @ViewBuilder
    private var heroSection: some View {
        let totals = model.monthTotals
        if totals.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(totals) { total in
                        TodayHero(total: total, showsCurrency: true)
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
        } else if let total = totals.first {
            TodayHero(total: total, showsCurrency: false)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "mic",
            title: "Aún no registras nada de \(LanaDateFormat.monthNameLowercased(model.month))",
            message: "Toca el micrófono y di, por ejemplo, 300 de súper.")
            .padding(.top, Space.xxl.rawValue)
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        TodayView(
            model: DashboardModel(
                store: InMemoryExpenseStore(),
                vocabularyStore: InMemoryCorrectionVocabularyStore(),
                cardStore: InMemoryCardStore(),
                sharedListStore: InMemorySharedListStore()),
            upcomingCardPaymentsModel: UpcomingCardPaymentsModel(
                cardStore: InMemoryCardStore(),
                cardPaymentStore: InMemoryCardPaymentStore()),
            settings: { Text("Ajustes") })
            .lanaTheme(theme)
    }
}

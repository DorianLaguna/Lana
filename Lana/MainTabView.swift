//
//  MainTabView.swift
//  Lana
//

import CardsFeature
import DashboardFeature
import EntryFeature
import InsightsFeature
import LanaCore
import LanaDesign
import OnboardingFeature
import SettingsFeature
import SharedFeature
import SwiftUI
import UIKit

/// La navegación del rediseño "Hoy primero" (sección 01): cuatro pestañas y
/// el micrófono dentro de una sola barra flotante (`LanaTabBar`).
///
/// Sigue siendo un `TabView` nativo con la barra del sistema escondida — una
/// barra armada a mano sobre un `Group { switch }` dejó la pantalla en blanco
/// en el dispositivo físico; `TabView` ancla bien cada pestaña y conserva su
/// estado al cambiar.
///
/// El Dashboard de antes se partió en dos pestañas: Hoy responde "¿cuánto me
/// queda?" y Mes explica en qué se fue. Ajustes salió de la barra y se empuja
/// desde el avatar de Hoy.
struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    /// Al volver a abrir la app, abre donde se quedó.
    @AppStorage("lana.selectedTab") private var selectedTab: MainTab = .hoy
    /// Cambia cada vez que se vuelve a Hoy, para regresar su scroll arriba.
    @State private var todayScrollTrigger = 0
    @State private var chrome = LanaChrome()
    /// `internal`, como los modelos de abajo: `MainTabViewRefresh.swift` arma
    /// la bandeja con los catálogos que la captura ya cargó, y `private` no
    /// cruza de archivo.
    @State var entryModel: EntryModel
    /// Los modelos que refresca `MainTabViewRefresh.swift` son `internal`:
    /// `private` no cruza de archivo.
    @State var dashboardModel: DashboardModel
    @State var yearModel: YearModel
    @State var recurringItemsModel: RecurringItemsModel
    @State var upcomingCardPaymentsModel: UpcomingCardPaymentsModel
    @State var cardsModel: CardsModel
    @State var sharedListModel: SharedListModel
    @State private var insightsModel: InsightsModel
    @State private var isInsightsPresented = false
    @State private var settingsModel: SettingsModel
    @State private var isCapturePresented = false
    /// El formulario de un movimiento que la app presenta por encima de las
    /// pestañas: el toque desde el detalle de una tarjeta (`CardsFeature` no
    /// puede construirlo) y "Agregar a mano" desde la captura.
    @State private var appEditExpenseModel: EditExpenseModel?
    /// "Agregar a mano" cierra la captura y abre el formulario en blanco; el
    /// formulario se presenta cuando la hoja terminó de irse, porque dos hojas
    /// no pueden presentarse a la vez desde la misma vista.
    @State private var opensManualEntryAfterCapture = false
    /// La bandeja "Por revisar", que se abre desde Hoy. Vive en
    /// `EntryFeature` —es la misma hoja de revisión de la captura— y
    /// `DashboardFeature` no puede importarla, así que la presenta la app.
    @State private var reviewTrayModel: IdentifiedModel<ReviewTrayModel>?
    /// De dónde salen los movimientos que la bandeja confirma. `internal` por
    /// lo mismo que `entryModel`.
    let store: any ExpenseStore
    /// El entorno real de Apple Pay, para reabrir la guía en `Mode.standalone`.
    private let environment: any ApplePayEnvironmentProbing
    /// Dispara la hoja de la guía de Apple Pay desde Tarjetas (R1.4).
    @State private var guidePresenter: ApplePayGuidePresenter
    /// El alto vigente de la hoja de captura.
    @State private var captureDetent: PresentationDetent = MainTabView.compactCaptureDetent

    /// El alto de arranque de la hoja de captura: un movimiento (sección 07).
    private static let compactCaptureDetent: PresentationDetent = .height(340)

    /// Un escalón intermedio para que la hoja crezca acompañando al dictado.
    private static let mediumCaptureDetent: PresentationDetent = .medium

    private func captureDetent(for height: CaptureHeight) -> PresentationDetent {
        switch height {
        case .compact: Self.compactCaptureDetent
        case .medium: Self.mediumCaptureDetent
        case .full: .large
        }
    }

    init(dependencies: AppDependencies, environment: any ApplePayEnvironmentProbing) {
        self.environment = environment
        store = dependencies.store
        _guidePresenter = State(initialValue: ApplePayGuidePresenter())
        _entryModel = State(initialValue: EntryModel(
            parser: dependencies.parser,
            store: dependencies.store,
            cardStore: dependencies.cardStore,
            speech: dependencies.speech,
            vocabularyStore: dependencies.vocabularyStore,
            sharedListStore: dependencies.sharedListStore))
        _dashboardModel = State(initialValue: DashboardModel(
            store: dependencies.store,
            vocabularyStore: dependencies.vocabularyStore,
            cardStore: dependencies.cardStore,
            sharedListStore: dependencies.sharedListStore,
            recurringItemStore: dependencies.recurringItemStore,
            cardPaymentStore: dependencies.cardPaymentStore))
        _yearModel = State(initialValue: YearModel(
            store: dependencies.store,
            cardStore: dependencies.cardStore,
            sharedListStore: dependencies.sharedListStore))
        _insightsModel = State(initialValue: InsightsModel(
            store: dependencies.store,
            sharedListStore: dependencies.sharedListStore,
            classifier: dependencies.classifier,
            narrator: dependencies.narrator,
            querying: dependencies.querying,
            cardStore: dependencies.cardStore,
            cardPaymentStore: dependencies.cardPaymentStore,
            recurringItemStore: dependencies.recurringItemStore))
        _recurringItemsModel = State(initialValue: RecurringItemsModel(
            recurringItemStore: dependencies.recurringItemStore,
            store: dependencies.store,
            cardStore: dependencies.cardStore))
        _upcomingCardPaymentsModel = State(initialValue: UpcomingCardPaymentsModel(
            cardStore: dependencies.cardStore,
            cardPaymentStore: dependencies.cardPaymentStore))
        _cardsModel = State(initialValue: CardsModel(
            cardStore: dependencies.cardStore,
            store: dependencies.store,
            cardPaymentStore: dependencies.cardPaymentStore))
        _sharedListModel = State(initialValue: SharedListModel(
            sharedListStore: dependencies.sharedListStore,
            expenseStore: dependencies.store,
            parser: dependencies.parser))
        _settingsModel = State(initialValue: SettingsModel(
            vocabularyStore: dependencies.vocabularyStore,
            syncStatusReporting: dependencies.syncStatus,
            // Ajustes solo CONSULTA la disponibilidad del dictado, nunca pide
            // el permiso (ADR-0015).
            speech: dependencies.speech))
    }

    /// Reabre la guía de Apple Pay como hoja en `Mode.standalone` (R1.4). Solo
    /// la app conoce `OnboardingFeature`, así que la fila de Tarjetas dispara
    /// este handler. Siempre devuelve uno: si el dispositivo no puede armar la
    /// automatización, lo explica la propia guía (R2.6).
    private func makeConfigureApplePayHandler() -> (() -> Void)? {
        { guidePresenter.model = IdentifiedModel(GuiaApplePayModel(mode: .standalone, environment: environment)) }
    }

    /// Los temas "siempre oscuro" también fuerzan el chrome del sistema
    /// (barra de estado, teclado), que `LanaColors` no controla.
    private var preferredScheme: ColorScheme? {
        settingsModel.selectedTheme.forcesDarkAppearance ? .dark : nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                model: dashboardModel,
                upcomingCardPaymentsModel: upcomingCardPaymentsModel,
                scrollToTopTrigger: todayScrollTrigger,
                onRefresh: refreshDashboard,
                onOpenMonth: { selectedTab = .mes },
                onOpenCards: { selectedTab = .tarjetas },
                onOpenReview: { reviewTrayModel = IdentifiedModel(makeReviewTrayModel()) },
                onExpenseChanged: { Task { await refreshAfterExpenseChange() } },
                settings: {
                    SettingsView(
                        model: settingsModel,
                        onOpenCards: { selectedTab = .tarjetas },
                        onOpenSystemSettings: openSettings)
                })
                .toolbarVisibility(.hidden, for: .tabBar)
                .tag(MainTab.hoy)

            MonthView(
                model: dashboardModel,
                recurringItemsModel: recurringItemsModel,
                yearModel: yearModel,
                onRefresh: refreshDashboard,
                onOpenInsights: { isInsightsPresented = true },
                onExpenseChanged: { Task { await refreshAfterExpenseChange() } },
                // Sin Apple Intelligence la fila del Análisis se apaga y dice
                // por qué; al tocarla, la hoja explica el caso y ofrece El año,
                // que sí funciona sin modelo (rediseño, sección 14).
                isInsightsAvailable: insightsModel.availability == .available)
                .toolbarVisibility(.hidden, for: .tabBar)
                .tag(MainTab.mes)

            CardsView(
                model: cardsModel,
                onExpenseTap: { expense in appEditExpenseModel = dashboardModel.makeEditExpenseModel(for: expense) },
                onConfigureApplePay: makeConfigureApplePayHandler())
                .toolbarVisibility(.hidden, for: .tabBar)
                .tag(MainTab.tarjetas)

            SharedListView(model: sharedListModel)
                .toolbarVisibility(.hidden, for: .tabBar)
                .tag(MainTab.gente)
        }
        .overlay(alignment: .bottom) {
            if !chrome.isTabBarHidden {
                LanaTabBar(
                    selection: $selectedTab,
                    pendingReviewCount: dashboardModel.needsReviewItems.count,
                    onMic: { isCapturePresented = true })
                    .padding(.horizontal, LanaMetrics.tabBarSideInset)
                    .padding(.bottom, LanaMetrics.tabBarBottomInset)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .ignoresSafeArea(.keyboard)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: chrome.isTabBarHidden)
        .environment(\.lanaChrome, chrome)
        .tint(LanaColors(theme: settingsModel.selectedTheme, colorScheme: colorScheme).accent)
        .lanaTheme(settingsModel.selectedTheme)
        .preferredColorScheme(preferredScheme)
        .onChange(of: selectedTab) { _, tab in
            guard tab == .hoy else { return }
            todayScrollTrigger += 1
        }
        .task { await refreshDashboard() }
        // Con la app viva en segundo plano desde antes del día de pago, el
        // sueldo no se registraba hasta matarla o jalar para refrescar.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshDashboard() }
        }
        .sheet(isPresented: $isCapturePresented, onDismiss: {
            // Por haber guardado o por arrastrarla a media frase: en los dos
            // casos hay que apagar el micrófono y limpiar el modelo, y la
            // próxima captura arranca compacta.
            Task { await entryModel.cancel() }
            captureDetent = Self.compactCaptureDetent
            if opensManualEntryAfterCapture {
                opensManualEntryAfterCapture = false
                appEditExpenseModel = dashboardModel.makeNewExpenseModel()
            }
        }, content: {
            EntryView(
                model: entryModel,
                onOpenSettings: openSettings,
                onDone: {
                    // Lo recién guardado se resalta un momento en Hoy: hace
                    // visible la consecuencia de haber dictado.
                    let saved = entryModel.lastSavedIDs
                    isCapturePresented = false
                    Task { await refreshAfterExpenseChange(highlighting: saved) }
                },
                onManualEntry: {
                    opensManualEntryAfterCapture = true
                    isCapturePresented = false
                },
                // Tocar el micrófono ya ES "quiero dictar" (ADR-0018).
                autoStartListening: true)
                .presentationDetents(
                    [Self.compactCaptureDetent, Self.mediumCaptureDetent, .large],
                    selection: $captureDetent)
                .presentationDragIndicator(.visible)
                .onChange(of: entryModel.captureHeight) { _, height in
                    withAnimation {
                        captureDetent = captureDetent(for: height)
                    }
                }
                // Un `.sheet` se presenta en un host aparte y no hereda el tema.
                .lanaTheme(settingsModel.selectedTheme)
                .preferredColorScheme(preferredScheme)
        })
        // El widget de Home Screen (ADR-0018) abre este link para saltar
        // directo a escuchar.
        .onOpenURL { url in
            guard url.scheme == "lana", url.host == "capture" else { return }
            isCapturePresented = true
        }
        .sheet(
            isPresented: $isInsightsPresented,
            onDismiss: { insightsModel.onDismiss() },
            content: {
                InsightsView(
                    model: insightsModel,
                    onOpenSettings: openSettings,
                    onDone: { isInsightsPresented = false })
                    .lanaTheme(settingsModel.selectedTheme)
                    .preferredColorScheme(preferredScheme)
            })
        .sheet(item: $reviewTrayModel) { identified in
            ReviewTrayView(model: identified.value, onDone: {
                reviewTrayModel = nil
                Task { await refreshAfterExpenseChange() }
            })
            .presentationDragIndicator(.visible)
            .lanaTheme(settingsModel.selectedTheme)
            .preferredColorScheme(preferredScheme)
        }
        .sheet(item: $appEditExpenseModel) { editModel in
            EditExpenseView(model: editModel, onDone: {
                appEditExpenseModel = nil
                Task { await refreshAfterExpenseChange() }
            })
            .lanaTheme(settingsModel.selectedTheme)
            .preferredColorScheme(preferredScheme)
        }
        // Reingreso a la guía de Apple Pay desde Tarjetas (R1.4).
        .sheet(item: $guidePresenter.model) { identified in
            GuiaApplePayView(
                model: identified.value,
                onOpenCardSettings: {
                    guidePresenter.model = nil
                    selectedTab = .tarjetas
                },
                onOpenShortcutsApp: { UIApplication.shared.openShortcutsApp() })
                .onChange(of: identified.value.isFinished) { _, isFinished in
                    guard isFinished else { return }
                    // Recorrerla hasta el cierre (no omitirla) baja de volumen
                    // la entrada en Tarjetas.
                    if identified.value.currentScreen == .closing {
                        cardsModel.markApplePayGuideSeen()
                    }
                    guidePresenter.model = nil
                }
                .presentationDragIndicator(.visible)
                .lanaTheme(settingsModel.selectedTheme)
                .preferredColorScheme(preferredScheme)
        }
    }
}

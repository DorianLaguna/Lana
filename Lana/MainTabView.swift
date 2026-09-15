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

enum Tab: Hashable {
    case dashboard
    case cards
    case shared
    case settings
}

/// El Dashboard es ahora también el hogar de la captura (Fase 6.5): no hay
/// tab de Captura aparte. Vuelta a `TabView` nativo — una barra armada a
/// mano (`Group { switch }.safeAreaInset`) dejó la pantalla en blanco con la
/// barra flotando a la mitad en el dispositivo físico; `TabView` sí ancla
/// bien al fondo. El micrófono es un botón flotante, elevado, encima de la
/// barra nativa — no reemplaza la barra, solo se le monta encima.
///
/// Compartido (Fase 8) entra como 4ª pestaña real, no como una hoja aparte
/// — el usuario pidió explícitamente "otro botón del menú". Con 4 pestañas
/// (número par), el mic centrado cae solo, sin geometría a mano, en el
/// hueco entre la 2ª (Tarjetas) y la 3ª (Compartido) — por eso el orden
/// importa: Dashboard/Tarjetas/Compartido/Ajustes, no otro.
struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: Tab = .dashboard
    @State private var entryModel: EntryModel
    /// Cuatro modelos `internal` y no `private`: los refresca
    /// `MainTabViewRefresh.swift`, y `private` no cruza de archivo. La vista
    /// anual vive aquí, y no dentro del Dashboard, para conservar el año al que
    /// el usuario ya navegó; el Análisis, porque `DashboardFeature` no puede
    /// importar `InsightsFeature`.
    @State var dashboardModel: DashboardModel
    @State var yearModel: YearModel
    @State private var insightsModel: InsightsModel
    @State private var isInsightsPresented = false
    @State private var recurringItemsModel: RecurringItemsModel
    @State private var upcomingCardPaymentsModel: UpcomingCardPaymentsModel
    @State var cardsModel: CardsModel
    @State var sharedListModel: SharedListModel
    @State private var settingsModel: SettingsModel
    @State private var isCapturePresented = false
    /// `CardsFeature` no puede construir esto (vive en `DashboardFeature`,
    /// y las features no se importan entre sí) — `ContentView` sí importa
    /// ambas, así que resuelve el tap desde el detalle de una tarjeta.
    @State private var cardsEditExpenseModel: EditExpenseModel?
    /// El entorno real de Apple Pay, para reabrir la guía en `Mode.standalone`
    /// desde Tarjetas (R1.4). Inyectado por `ContentView`.
    private let environment: any ApplePayEnvironmentProbing
    /// Estado que dispara la hoja de la guía de Apple Pay. La fila de
    /// "Configurar Apple Pay" en Tarjetas (`CardsView.onConfigureApplePay`)
    /// fija aquí el modelo de la guía en `Mode.standalone`; esta vista lo
    /// observa (`.sheet(item:)`) para presentar y cerrar la hoja (R1.4).
    @State private var guidePresenter: ApplePayGuidePresenter
    /// El alto vigente de la hoja de captura — ver el `.sheet` de abajo.
    @State private var captureDetent: PresentationDetent = MainTabView.compactCaptureDetent

    /// El alto de arranque de la hoja de captura: lo justo para "escuchando"
    /// sin dejar un hueco vacío debajo.
    private static let compactCaptureDetent: PresentationDetent = .height(360)

    /// Un escalón intermedio: cabe una frase de un par de renglones más sin
    /// tapar toda la pantalla. La hoja pasa por aquí antes de la pantalla
    /// completa, para que crezca acompañando al dictado en vez de pegar un
    /// brinco a `.large` a media frase.
    private static let mediumCaptureDetent: PresentationDetent = .height(560)

    /// Traduce el escalón que pide el modelo (`CaptureHeight`) al detent
    /// concreto que entiende la hoja.
    private func captureDetent(for height: CaptureHeight) -> PresentationDetent {
        switch height {
        case .compact: Self.compactCaptureDetent
        case .medium: Self.mediumCaptureDetent
        case .full: .large
        }
    }

    init(dependencies: AppDependencies, environment: any ApplePayEnvironmentProbing) {
        self.environment = environment
        let presenter = ApplePayGuidePresenter()
        _guidePresenter = State(initialValue: presenter)
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
            sharedListStore: dependencies.sharedListStore))
        _yearModel = State(initialValue: YearModel(
            store: dependencies.store,
            cardStore: dependencies.cardStore,
            sharedListStore: dependencies.sharedListStore))
        _insightsModel = State(initialValue: InsightsModel(
            store: dependencies.store,
            sharedListStore: dependencies.sharedListStore,
            classifier: dependencies.classifier,
            narrator: dependencies.narrator,
            querying: dependencies.querying))
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
            // El mismo transcriptor que usa la captura: Ajustes solo CONSULTA
            // su disponibilidad para mostrar el estado del permiso, nunca lo
            // pide (eso es cosa del micrófono, ADR-0015).
            speech: dependencies.speech))
    }

    /// Reabre la guía de Apple Pay como hoja en `Mode.standalone` (R1.4). Su
    /// hogar es Tarjetas, no Ajustes: es la captura automática de gastos vía
    /// Atajos, no un método de pago (arquitectura de información de Ajustes:
    /// sin sección de Pagos). Ni `CardsView` ni `SettingsView` pueden
    /// construir `GuiaApplePayView` (vive en `OnboardingFeature`, y las
    /// features no se importan entre sí), así que la fila solo dispara este
    /// handler; aquí —el único que conoce `OnboardingFeature`— se arma el
    /// modelo en `Mode.standalone`, cuyo cierre (`isFinished`) solo cierra la
    /// hoja, sin avanzar ningún onboarding.
    ///
    /// Siempre devuelve un handler, aunque el dispositivo no pueda armar la
    /// automatización: quien explica esa incompatibilidad es la propia guía
    /// (R2.6), y esconder la entrada dejaría al usuario sin saber por qué no
    /// está. El tipo sigue siendo opcional porque `CardsView` lo declara así
    /// para sus previews.
    private func makeConfigureApplePayHandler() -> (() -> Void)? {
        { guidePresenter.model = IdentifiedModel(GuiaApplePayModel(mode: .standalone, environment: environment)) }
    }

    /// Nunca `@Environment(\.lana)` aquí: esta vista es la que APLICA
    /// `.lanaTheme(...)` a su propio contenido (la `TabView` de abajo) — el
    /// entorno que ese modificador arma solo llega a los descendientes de
    /// esa `TabView`, nunca de vuelta a las propiedades de `MainTabView`
    /// misma. Leerlo así dejaba el micrófono y el tinte de tabs siempre en
    /// Cobalto sin importar el tema elegido — el bug real detrás de "no veo
    /// esos colores en ningún lado".
    private var lana: LanaColors {
        LanaColors(theme: settingsModel.selectedTheme, colorScheme: colorScheme)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                model: dashboardModel,
                recurringItemsModel: recurringItemsModel,
                upcomingCardPaymentsModel: upcomingCardPaymentsModel,
                yearModel: yearModel,
                // `SharedFeature` no puede construir esto (las features no
                // se importan entre sí) — un gasto editado o borrado aquí
                // puede ser compartido, y sin este aviso el saldo en
                // "Compartido" se quedaba con la cifra vieja hasta salir y
                // volver a entrar a esa lista.
                onExpenseChanged: { Task { await refreshSurfacesOutsideDashboard() } },
                onOpenInsights: { isInsightsPresented = true })
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                .tag(Tab.dashboard)

            CardsView(
                model: cardsModel,
                onExpenseTap: { expense in cardsEditExpenseModel = dashboardModel.makeEditExpenseModel(for: expense) },
                onConfigureApplePay: makeConfigureApplePayHandler())
                .tabItem { Label("Tarjetas", systemImage: "creditcard") }
                .tag(Tab.cards)

            SharedListView(model: sharedListModel)
                .tabItem { Label("Compartido", systemImage: "person.2") }
                .tag(Tab.shared)

            SettingsView(
                model: settingsModel,
                // El puntero a la guía de Apple Pay dentro de "Cómo funciona
                // Lana" salta a su hogar real, la pestaña Tarjetas; antes era
                // una frase que había que seguir a mano.
                onOpenCards: { selectedTab = .cards },
                onOpenSystemSettings: openSettings)
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(lana.accent)
        .lanaTheme(settingsModel.selectedTheme)
        // Los temas con `forcesDarkAppearance` (Obsidiana, Ámbar, Zafiro)
        // ya fuerzan su propio fondo casi negro en `LanaColors`
        // (ADR-0016/ADR-0017), pero eso solo cubre lo que Lana dibuja — sin
        // esto la barra de estado y el teclado del sistema seguían el modo
        // claro/oscuro real del dispositivo, rompiendo la sensación de
        // "siempre oscuro" en el resto del chrome que Lana no controla.
        // `nil` para los demás temas: siguen el sistema, como siempre.
        .preferredColorScheme(settingsModel.selectedTheme.forcesDarkAppearance ? .dark : nil)
        .overlay(alignment: .bottom) {
            micButton
                // Con 4 tabs (número par), este overlay centrado cae solo
                // en el hueco entre Tarjetas y Compartido — ver el comment
                // de `Tab`. Padding más chico que antes (54→40) para que
                // el círculo, ahora más grande, se sienta encajado en el
                // borde superior de la barra nativa en vez de flotando
                // muy por encima — el tamaño exacto todavía necesita una
                // pasada visual en el device real, esto es la primera
                // aproximación por código.
                .padding(.bottom, 40)
        }
        .sheet(isPresented: $isCapturePresented, onDismiss: {
            // Se cerró la hoja: por haber guardado, o arrastrándola hacia
            // abajo a media frase. En los dos casos hay que apagar el
            // micrófono y limpiar el modelo, y solo este callback corre en
            // los dos — `onDone` no se entera de un arrastre.
            Task { await entryModel.cancel() }
            // El `onChange` de adentro ya no corre (la hoja se fue), así
            // que el alto se regresa aquí: la próxima captura arranca
            // compacta, no en la pantalla completa que dejó la anterior.
            captureDetent = Self.compactCaptureDetent
        }, content: {
            EntryView(
                model: entryModel,
                onOpenSettings: openSettings,
                onDone: {
                    isCapturePresented = false
                    Task { await refreshAfterExpenseChange() }
                },
                // Siempre, no solo desde el widget (ADR-0018): tocar el
                // micrófono ya ES "quiero dictar". Antes había que tocarlo
                // dos veces — una para abrir la hoja y otra para el mic de
                // adentro — y el segundo toque no decidía nada que el
                // primero no hubiera dicho ya. Si el dictado no arranca
                // (sin permiso, o el modelo no disponible), la hoja se
                // queda en su pantalla de siempre con el mic a la mano.
                autoStartListening: true)
                // No pantalla completa — es un momento rápido de captura,
                // no una pantalla propia (pedido explícito del usuario).
                // `.medium` dejaba mucho espacio vacío bajo el contenido
                // corto de "escuchar", así que el alto de arranque es una
                // altura fija más chica.
                //
                // Pero se sube solo cuando el contenido lo pide
                // (`EntryModel.captureHeight`): al revisar, y al dictar. El
                // dictado crece por escalones —compacta, media, completa—
                // en vez de brincar de golpe a pantalla completa a media
                // frase, para que la hoja acompañe lo que se va diciendo.
                // Antes había que arrastrarla a mano, y el método de pago
                // —último campo de `DraftCard`— quedaba fuera de alcance
                // hasta hacerlo. Se sigue pudiendo arrastrar en los tres
                // sentidos; esto solo elige el punto de partida de cada
                // momento.
                .presentationDetents(
                    [Self.compactCaptureDetent, Self.mediumCaptureDetent, .large],
                    selection: $captureDetent)
                .presentationDragIndicator(.visible)
                .onChange(of: entryModel.captureHeight) { _, height in
                    withAnimation {
                        captureDetent = captureDetent(for: height)
                    }
                }
                // El contenido de un `.sheet` se presenta en un host aparte
                // y NO hereda el `.lanaTheme(...)` que la `TabView` de arriba
                // aplica — sin esto, la hoja de captura (mic, ondas de voz)
                // caía en el tema por defecto (Cobalto), viéndose de otro
                // color que el mic del dashboard. Repetir el tema aquí lo
                // ancla al que el usuario eligió (p.ej. Zafiro).
                .lanaTheme(settingsModel.selectedTheme)
                .preferredColorScheme(settingsModel.selectedTheme.forcesDarkAppearance ? .dark : nil)
        })
        // El widget de Home Screen (ADR-0018) abre este link para saltar
        // directo a escuchar — el menor número de toques posible entre
        // "quiero registrar algo" y "ya estoy hablando". Ya no necesita
        // encender nada: la hoja arranca escuchando venga de donde venga.
        .onOpenURL { url in
            guard url.scheme == "lana", url.host == "capture" else { return }
            isCapturePresented = true
        }
        // `onDismiss` tira lo analizado: al reabrir, los movimientos pueden
        // ser otros. Y como las demás hojas, esta no hereda el `.lanaTheme` de
        // la `TabView` — hay que reaplicarlo aquí.
        .sheet(
            isPresented: $isInsightsPresented,
            onDismiss: { insightsModel.onDismiss() },
            content: {
                InsightsView(
                    model: insightsModel,
                    onOpenSettings: openSettings,
                    onDone: { isInsightsPresented = false })
                    .lanaTheme(settingsModel.selectedTheme)
                    .preferredColorScheme(settingsModel.selectedTheme.forcesDarkAppearance ? .dark : nil)
            })
        .sheet(item: $cardsEditExpenseModel) { editModel in
            EditExpenseView(model: editModel, onDone: {
                cardsEditExpenseModel = nil
                Task { await refreshAfterExpenseChange() }
            })
            // Igual que la hoja de captura: un `.sheet` no hereda el
            // `.lanaTheme` de la `TabView`, hay que reaplicarlo aquí.
            .lanaTheme(settingsModel.selectedTheme)
            .preferredColorScheme(settingsModel.selectedTheme.forcesDarkAppearance ? .dark : nil)
        }
        // Reingreso a la guía de Apple Pay desde Tarjetas (R1.4). En
        // `Mode.standalone` la guía no avanza ningún onboarding; su `onFinish`
        // solo marca `isFinished`, que observamos para cerrar la hoja. Le
        // pasamos los mismos handlers de cruce de feature que en onboarding:
        // ir a Tarjetas (R3.4) — ya estando dentro de la app, saltamos a esa
        // pestaña — y abrir la app Atajos (best-effort).
        .sheet(item: $guidePresenter.model) { identified in
            GuiaApplePayView(
                model: identified.value,
                onOpenCardSettings: {
                    guidePresenter.model = nil
                    selectedTab = .cards
                },
                onOpenShortcutsApp: { UIApplication.shared.openShortcutsApp() })
                .onChange(of: identified.value.isFinished) { _, isFinished in
                    guard isFinished else { return }
                    // Terminó recorriéndola hasta el cierre (no omitiéndola a
                    // media guía): la entrada en Tarjetas baja de volumen.
                    // "Omitir" solo se ofrece FUERA del cierre, así que la
                    // pantalla en que quedó distingue los dos casos — misma
                    // discriminación que hace `OnboardingView`.
                    if identified.value.currentScreen == .closing {
                        cardsModel.markApplePayGuideSeen()
                    }
                    guidePresenter.model = nil
                }
                // Como cualquier otra hoja de la app: que se vea que se puede
                // arrastrar para cerrar.
                .presentationDragIndicator(.visible)
                // Igual que las otras hojas: reaplica el tema, que un
                // `.sheet` no hereda de la `TabView`.
                .lanaTheme(settingsModel.selectedTheme)
                .preferredColorScheme(settingsModel.selectedTheme.forcesDarkAppearance ? .dark : nil)
        }
    }

    /// Elevado y con el color de acento, a propósito distinto a un tab más
    /// — es el camino principal para agregar un gasto (el `+` del Dashboard
    /// es la salida manual, ADR-0035), no un destino de navegación. Abre la
    /// hoja ya escuchando: un solo toque entre "quiero registrar algo" y
    /// "ya estoy hablando".
    /// El fondo mezcla `accent` y `highlight` — el par curado del tema
    /// completo (ADR-0006), no solo el primario. `Color.gradient` genera un
    /// degradado monocromático del mismo tono, así que aunque cada tema
    /// tiene dos colores elegidos, el segundo nunca se veía en ningún lado
    /// salvo en el swatch diminuto del selector de tema en Ajustes — el
    /// elemento flotante que se ve en cada pantalla es el lugar obvio para
    /// que el par completo sea visible de verdad.
    private var micButton: some View {
        Button {
            isCapturePresented = true
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                // 76pt — a juego con el mic de `ListeningView`, agrandado
                // desde 58pt para que se sienta el centro visual de la
                // barra (pedido explícito del usuario), no un botón
                // flotante aparte.
                .frame(width: 76, height: 76)
                // El relleno es fijo y sólido: el mic no parpadea ni cambia
                // de opacidad. Toda la señal de "aquí hay inteligencia" la
                // lleva el halo detrás, no el símbolo.
                .background(
                    LinearGradient(
                        colors: [lana.accent, lana.highlight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    in: Circle())
                // En el dashboard la IA está disponible pero en reposo: el
                // halo apenas asoma y se deforma lentísimo. Cambia de
                // carácter dentro de la hoja de captura, según el `stage`.
                .background(IntelligenceHalo(state: .idle))
                .shadow(color: lana.accent.opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

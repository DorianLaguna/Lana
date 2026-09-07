//
//  MainTabView.swift
//  Lana
//

import CardsFeature
import DashboardFeature
import EntryFeature
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
    @State private var dashboardModel: DashboardModel
    @State private var recurringItemsModel: RecurringItemsModel
    @State private var upcomingCardPaymentsModel: UpcomingCardPaymentsModel
    @State private var cardsModel: CardsModel
    @State private var sharedListModel: SharedListModel
    @State private var settingsModel: SettingsModel
    @State private var isCapturePresented = false
    /// `CardsFeature` no puede construir esto (vive en `DashboardFeature`,
    /// y las features no se importan entre sí) — `ContentView` sí importa
    /// ambas, así que resuelve el tap desde el detalle de una tarjeta.
    @State private var cardsEditExpenseModel: EditExpenseModel?
    /// El entorno real de Apple Pay, para reabrir la guía en `Mode.standalone`
    /// desde Ajustes (R1.4). Inyectado por `ContentView`.
    private let environment: any ApplePayEnvironmentProbing
    /// Puente entre el handler `onConfigureApplePay` que `SettingsModel` recibe
    /// en `init` y el estado de esta vista. `SettingsModel` se construye en el
    /// `init` de `MainTabView`, cuando el `@State` de la vista todavía no está
    /// listo para mutarse desde una closure — así que la closure fija el modelo
    /// de la guía en este objeto de referencia, que la vista observa para
    /// presentar la hoja (R1.4).
    @State private var guidePresenter: ApplePayGuidePresenter
    /// `true` mientras se procesa un deep link del widget (ADR-0018) — se
    /// consume una sola vez: se prende justo antes de presentar la hoja de
    /// captura y se apaga al cerrarla, para que un toque normal del
    /// micrófono después no arranque a escuchar solo por accidente.
    @State private var autoStartListening = false

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
            // Reabre la guía de Apple Pay como hoja en `Mode.standalone` (R1.4).
            // `SettingsModel` no puede construir `GuiaApplePayView` (vive en
            // `OnboardingFeature`, y las features no se importan entre sí), así
            // que solo dispara este handler; el target de la app arma el modelo
            // en `Mode.standalone`, cuyo cierre (`isFinished`) solo cierra la
            // hoja, sin avanzar ningún onboarding.
            onConfigureApplePay: {
                presenter.model = IdentifiedModel(GuiaApplePayModel(mode: .standalone, environment: environment))
            }))
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
                // `SharedFeature` no puede construir esto (las features no
                // se importan entre sí) — un gasto editado o borrado aquí
                // puede ser compartido, y sin este aviso el saldo en
                // "Compartido" se quedaba con la cifra vieja hasta salir y
                // volver a entrar a esa lista.
                onExpenseChanged: { Task { await refreshSurfacesOutsideDashboard() } })
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
                .tag(Tab.dashboard)

            CardsView(
                model: cardsModel,
                onExpenseTap: { expense in cardsEditExpenseModel = dashboardModel.makeEditExpenseModel(for: expense) })
                .tabItem { Label("Tarjetas", systemImage: "creditcard") }
                .tag(Tab.cards)

            SharedListView(model: sharedListModel)
                .tabItem { Label("Compartido", systemImage: "person.2") }
                .tag(Tab.shared)

            SettingsView(model: settingsModel)
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
        .sheet(isPresented: $isCapturePresented) {
            EntryView(
                model: entryModel,
                onOpenSettings: openSettings,
                onDone: {
                    isCapturePresented = false
                    autoStartListening = false
                    entryModel.startOver()
                    Task { await refreshAfterExpenseChange() }
                },
                autoStartListening: autoStartListening)
                // No pantalla completa — es un momento rápido de captura,
                // no una pantalla propia (pedido explícito del usuario).
                // `.medium` dejaba mucho espacio vacío bajo el contenido
                // corto de "escuchar"; una altura fija más chica, con
                // `.large` disponible arrastrando hacia arriba para cuando
                // hay varios borradores que revisar.
                .presentationDetents([.height(360), .large])
                .presentationDragIndicator(.visible)
        }
        // El widget de Home Screen (ADR-0018) abre este link para saltar
        // directo a escuchar — el menor número de toques posible entre
        // "quiero registrar algo" y "ya estoy hablando".
        .onOpenURL { url in
            guard url.scheme == "lana", url.host == "capture" else { return }
            autoStartListening = true
            isCapturePresented = true
        }
        .sheet(item: $cardsEditExpenseModel) { editModel in
            EditExpenseView(model: editModel, onDone: {
                cardsEditExpenseModel = nil
                Task { await refreshAfterExpenseChange() }
            })
        }
        // Reingreso a la guía de Apple Pay desde Ajustes (R1.4). En
        // `Mode.standalone` la guía no avanza ningún onboarding; su `onFinish`
        // solo marca `isFinished`, que observamos para cerrar la hoja. Le
        // pasamos los mismos handlers de cruce de feature que en onboarding:
        // "Ajustes → Tarjetas" (R3.4) — ya estando dentro de la app, saltamos a
        // la pestaña de Tarjetas — y abrir la app Atajos (best-effort).
        .sheet(item: $guidePresenter.model) { identified in
            GuiaApplePayView(
                model: identified.value,
                onOpenCardSettings: {
                    guidePresenter.model = nil
                    selectedTab = .cards
                },
                onOpenShortcutsApp: { UIApplication.shared.openShortcutsApp() })
                .onChange(of: identified.value.isFinished) { _, isFinished in
                    if isFinished {
                        guidePresenter.model = nil
                    }
                }
        }
    }

    /// Elevado y con el color de acento, a propósito distinto a un tab más
    /// — es la única forma de agregar un gasto, no un destino de navegación.
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
                .background(
                    LinearGradient(
                        colors: [lana.accent, lana.highlight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    in: Circle())
                .shadow(color: lana.accent.opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    /// Todo lo que puede quedar viejo cuando se crea, edita o borra un
    /// gasto desde cualquier punto de la app. Un solo lugar a propósito:
    /// cada hoja tenía su propia lista de refrescos y capturar un gasto
    /// nuevo refrescaba Dashboard y Compartido pero no Tarjetas, así que
    /// estando dentro de una tarjeta el cargo recién capturado no aparecía
    /// hasta salir y volver a entrar (ADR-0032). Agregar una pantalla nueva
    /// que dependa de los gastos se hace aquí, no en cada `onDone`.
    private func refreshAfterExpenseChange() async {
        await dashboardModel.onAppear()
        await refreshSurfacesOutsideDashboard()
    }

    /// Lo mismo, sin el Dashboard — para cuando el aviso viene de adentro
    /// del propio Dashboard, que ya se refrescó a sí mismo antes de avisar
    /// (`DashboardView`, hoja de editar). Refrescarlo otra vez sería una
    /// lectura de más y un parpadeo de su spinner.
    private func refreshSurfacesOutsideDashboard() async {
        await cardsModel.onAppear()
        // `cardsModel.onAppear()` solo refresca la lista de tarjetas y su
        // deuda — el detalle empujado en el stack (si el usuario está
        // drilled-down en una tarjeta) es una instancia aparte con su
        // propia copia de gastos.
        await cardsModel.refreshCurrentCardDetail()
        // El gasto puede ser compartido.
        await sharedListModel.refreshCurrentDetail()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    MainTabView(dependencies: .preview(), environment: InMemoryApplePayEnvironment())
}

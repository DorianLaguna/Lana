//
//  ContentView.swift
//  Lana
//

import CardsFeature
import DashboardFeature
import EntryFeature
import LanaDesign
import SettingsFeature
import SharedFeature
import SwiftUI
import UIKit

/// La raíz de la app: arma `AppDependencies` (async por `CoreDataExpenseStore`)
/// y solo entonces muestra la navegación real.
struct ContentView: View {
    let appDelegate: AppDelegate
    @State private var dependencies: AppDependencies?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let dependencies {
                MainTabView(dependencies: dependencies)
            } else if let loadError {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "No se pudo iniciar", message: loadError)
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                let dependencies = try await AppDependencies.live()
                self.dependencies = dependencies
                // Conecta el store real para que `AppDelegate` pueda
                // aceptar invitaciones de `CKShare` (ADR-0020) — incluye
                // procesar cualquiera que haya llegado mientras esto cargaba.
                if let concreteExpenseStore = dependencies.concreteExpenseStore {
                    appDelegate.attach(store: concreteExpenseStore)
                }
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

private enum Tab: Hashable {
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
private struct MainTabView: View {
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
    /// `true` mientras se procesa un deep link del widget (ADR-0018) — se
    /// consume una sola vez: se prende justo antes de presentar la hoja de
    /// captura y se apaga al cerrarla, para que un toque normal del
    /// micrófono después no arranque a escuchar solo por accidente.
    @State private var autoStartListening = false

    init(dependencies: AppDependencies) {
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
            syncStatusReporting: dependencies.syncStatus))
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
                onExpenseChanged: { Task { await sharedListModel.refreshCurrentDetail() } })
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
                    Task {
                        await dashboardModel.onAppear()
                        // Un gasto capturado aquí puede ser compartido.
                        await sharedListModel.refreshCurrentDetail()
                    }
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
                Task {
                    await dashboardModel.onAppear()
                    await cardsModel.onAppear()
                    // `cardsModel.onAppear()` solo refresca la lista de
                    // tarjetas y su deuda — el detalle empujado en el stack
                    // (si el usuario está drilled-down en una tarjeta) es
                    // una instancia aparte con su propia copia de gastos.
                    await cardsModel.refreshCurrentCardDetail()
                    // El gasto editado/borrado puede ser compartido.
                    await sharedListModel.refreshCurrentDetail()
                }
            })
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

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    MainTabView(dependencies: .preview())
}

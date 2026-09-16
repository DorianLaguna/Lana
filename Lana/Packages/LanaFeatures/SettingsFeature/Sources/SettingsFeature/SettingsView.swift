import LanaCore
import LanaDesign
import SwiftUI

/// Ajustes (rediseño, sección 12): lo que se visita dos veces al año. Por eso
/// salió de la barra de pestañas y se empuja desde el avatar de Hoy —liberar
/// un espacio permanente para algo que casi no se usa era el cambio más fácil
/// de la navegación.
///
/// Cuatro encabezados para ocho filas se reducen a dos, el estado de iCloud
/// sube a la tarjeta de cuenta, y el tema se elige aquí mismo: ya no hace
/// falta entrar a otra pantalla para cambiarlo.
public struct SettingsView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: SettingsModel
    /// Salta a la pestaña Tarjetas — el hogar de la guía de Apple Pay, que no
    /// vive en Ajustes. `SettingsFeature` no puede navegar a otra feature.
    private let onOpenCards: (() -> Void)?
    /// Abre la página de Lana en los Ajustes del sistema, para el permiso de
    /// micrófono y dictado. La feature nunca importa UIKit.
    private let onOpenSystemSettings: (() -> Void)?

    public init(
        model: SettingsModel,
        onOpenCards: (() -> Void)? = nil,
        onOpenSystemSettings: (() -> Void)? = nil) {
        self.model = model
        self.onOpenCards = onOpenCards
        self.onOpenSystemSettings = onOpenSystemSettings
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                accountCard
                    .padding(.bottom, Space.p26.rawValue)

                SectionHeader("Tema", style: .minor)
                    .padding(.bottom, Space.p12.rawValue)
                themeCard
                    .padding(.bottom, Space.p26.rawValue)

                SectionHeader("Lana", style: .minor)
                    .padding(.bottom, Space.p12.rawValue)
                lanaCard
                    .padding(.bottom, Space.p26.rawValue)

                aboutCard
                    .padding(.bottom, Space.p22.rawValue)

                footer
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p22.rawValue)
            .tabBarClearance(.noTabBar)
        }
        .background(lana.bg)
        .navigationTitle("Ajustes")
        .lanaInlineNavigationTitle()
        .hidesLanaTabBar()
        .task { await model.onAppear() }
        // `NavRow` es un botón, no un `NavigationLink`: la navegación pasa por
        // este estado. Ajustes se empuja dentro del stack de Hoy, así que no
        // puede tener un path propio.
        .navigationDestination(item: $destination) { destination in
            Group {
                switch destination {
                case .lanaInfo: LanaInfoView(onOpenCards: onOpenCards)
                case .lanaLearning: LanaLearningView(model: model)
                case .data: DataSettingsView(model: model)
                case .privacy: PrivacyView()
                case .aboutLana: AboutLanaView()
                }
            }
            .hidesLanaTabBar()
        }
    }

    // MARK: - Cuenta

    /// El estado de iCloud vive aquí, no en una sección propia: es un dato de
    /// la cuenta, no un tema aparte.
    private var accountCard: some View {
        LanaCard(padding: .md, radius: .cardLarge) {
            HStack(spacing: Space.p14.rawValue) {
                InitialAvatar(name: "Lana", diameter: LanaMetrics.avatarLarge, isRaised: true)
                VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                    Text("Tu Lana")
                        .lanaFont(.pushTitle)
                        .foregroundStyle(lana.ink)
                    Text(syncSummary)
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(syncColor)
                }
                Spacer(minLength: Space.sm.rawValue)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var syncSummary: String {
        switch model.syncStatus {
        case .disabled: "Sin iCloud · todo vive en este iPhone"
        case .syncing: "Sincronizando…"
        case let .synced(lastSuccess): "iCloud al día · \(lastSuccess.formatted(.relative(presentation: .named)))"
        case .failed: "No se pudo respaldar la última vez"
        }
    }

    private var syncColor: Color {
        switch model.syncStatus {
        case .synced: lana.positive
        case .syncing: lana.ink42
        case .disabled, .failed: lana.attention
        }
    }

    // MARK: - Tema

    /// Elegir tema ya no requiere entrar a otra pantalla: los ocho caben aquí
    /// y se aplican al instante.
    private var themeCard: some View {
        LanaCard(padding: .md, radius: .cardLarge) {
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                HStack(spacing: Space.p9.rawValue) {
                    ForEach(LanaTheme.allCases) { theme in
                        ThemeSwatch(theme: theme, isSelected: theme == model.selectedTheme) {
                            withAnimation(.easeInOut(duration: 0.25)) { model.selectTheme(theme) }
                        }
                    }
                }
                Text(model.selectedTheme.appearanceDescription)
                    .lanaFont(.detail)
                    .foregroundStyle(lana.ink55)
            }
        }
    }

    // MARK: - Lana

    private var lanaCard: some View {
        LanaCard(padding: nil, radius: .cardLarge) {
            VStack(spacing: 0) {
                NavRow("Cómo funciona Lana", subtitle: "Hablas, entiende, registra") {
                    destination = .lanaInfo
                }
                HairlineDivider()
                NavRow("Aprendizaje", subtitle: learnedWordsSubtitle) {
                    destination = .lanaLearning
                }
                if let availability = model.speechAvailability {
                    HairlineDivider()
                    speechRow(availability)
                }
                HairlineDivider()
                NavRow("iCloud", subtitle: syncSummary, subtitleTone: syncTone) {
                    destination = .data
                }
            }
        }
    }

    private var learnedWordsSubtitle: String {
        if model.isLoading {
            return "Cargando…"
        }
        let count = model.learnedWordCount
        return count == 1 ? "1 palabra aprendida" : "\(count) palabras aprendidas"
    }

    private var syncTone: LanaTone {
        switch model.syncStatus {
        case .synced: .positive
        case .syncing: .muted
        case .disabled, .failed: .attention
        }
    }

    /// Un permiso concedido es un dato, no una acción: solo lleva a Ajustes
    /// del sistema cuando hay algo que arreglar. El tono nunca reprocha — no
    /// haber dado permiso no es un error del usuario.
    private func speechRow(_ availability: SpeechAvailability) -> some View {
        NavRow(
            "Micrófono y dictado",
            subtitle: speechSubtitle(availability),
            subtitleTone: availability == .available ? .positive : .attention,
            showsChevron: isSpeechActionable(availability),
            action: {
                guard isSpeechActionable(availability) else { return }
                onOpenSystemSettings?()
            })
    }

    private func isSpeechActionable(_ availability: SpeechAvailability) -> Bool {
        availability == .permissionDenied || availability == .restricted
    }

    private func speechSubtitle(_ availability: SpeechAvailability) -> String {
        switch availability {
        case .available: "Permitido"
        case .permissionNotDetermined: "Se pide la primera vez que uses el micrófono"
        case .permissionDenied: "Sin permiso — actívalo en Ajustes"
        case .restricted: "Restringido en este dispositivo"
        case .unavailable: "El dictado no está disponible en este idioma"
        }
    }

    // MARK: - Acerca de

    /// La versión deja de ser una fila propia y viaja como valor de "Acerca de".
    private var aboutCard: some View {
        LanaCard(padding: nil, radius: .cardLarge) {
            VStack(spacing: 0) {
                NavRow("Privacidad") { destination = .privacy }
                HairlineDivider()
                NavRow("Acerca de Lana", value: model.appVersion) { destination = .aboutLana }
            }
        }
    }

    private var footer: some View {
        Text("Tus movimientos viven en tu iCloud.\nLa voz y el análisis se procesan en tu iPhone.")
            .lanaFont(.rowSubtitle)
            .foregroundStyle(lana.ink30)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// El destino que se está empujando. `NavRow` es un botón, no un
    /// `NavigationLink`, así que la navegación pasa por aquí.
    @State private var destination: SettingsDestination?
}

/// Destinos empujables desde Ajustes. El tema ya no está: se elige en la
/// propia pantalla.
enum SettingsDestination: Hashable {
    case lanaInfo
    case lanaLearning
    case data
    case privacy
    case aboutLana
}

/// Un swatch del selector de tema, pintado con SUS propios colores para que se
/// vea el aspecto real de cada opción.
private struct ThemeSwatch: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.lana) private var lana
    let theme: LanaTheme
    let isSelected: Bool
    let onTap: () -> Void

    private var colors: LanaColors {
        LanaColors(theme: theme, colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(colors.accentFill)
                .frame(width: LanaMetrics.themeSwatch, height: LanaMetrics.themeSwatch)
                .overlay {
                    // La palomita, no solo el borde: el color nunca es el único
                    // portador de información.
                    if isSelected {
                        Image(systemName: "checkmark")
                            .lanaFont(.rowSubtitle)
                            .fontWeight(.bold)
                            .foregroundStyle(colors.onAccent)
                    }
                }
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(lana.ink, lineWidth: LanaMetrics.outline)
                    }
                }
                .frame(width: LanaMetrics.minTouchTarget, height: LanaMetrics.minTouchTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            SettingsView(
                model: SettingsModel(
                    vocabularyStore: InMemoryCorrectionVocabularyStore(seed: [
                        CorrectionEntry(term: "bocina", category: "ocio", useCount: 4)
                    ]),
                    syncStatusReporting: InMemorySyncStatusReporting(.synced(lastSuccess: .now)),
                    speech: InMemorySpeechTranscribing(),
                    userDefaults: UserDefaults(suiteName: "preview") ?? .standard),
                onOpenCards: {},
                onOpenSystemSettings: {})
        }
        .lanaTheme(theme)
    }
}

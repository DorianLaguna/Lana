import LanaCore
import LanaDesign
import SwiftUI

/// Ajustes: cuatro secciones deliberadas —Lana, Apariencia, Datos, Acerca
/// de— cada una una fila-resumen que abre su pantalla propia. La pantalla
/// principal ya no muestra el contenido expandido (vocabulario, grid de
/// temas): eso se movió a `LanaLearningView` y `ThemeSettingsView` para que
/// Ajustes se lea de un vistazo y no domine ninguna pieza.
///
/// Sin lógica propia — refleja `SettingsModel` (Docs/ARCHITECTURE.md). La
/// navegación sigue el patrón `NavigationLink(value:)` +
/// `navigationDestination(for:)` del resto de la app.
public struct SettingsView: View {
    @Environment(\.lana) private var lana
    private let model: SettingsModel
    /// Salta a la pestaña Tarjetas — el hogar de la guía de Apple Pay, que ya
    /// no vive en Ajustes. `SettingsFeature` no puede navegar a otra feature
    /// (no se importan entre sí, Docs/ARCHITECTURE.md), así que el contenedor
    /// inyecta el salto. `nil` en previews: entonces el puntero se queda como
    /// texto, sin botón.
    private let onOpenCards: (() -> Void)?
    /// Abre la página de Lana en los Ajustes del sistema, para el permiso de
    /// micrófono y dictado. Mismo patrón que `EntryView(onOpenSettings:)`:
    /// la feature nunca importa UIKit.
    private let onOpenSystemSettings: (() -> Void)?

    /// - Parameters:
    ///   - model: el estado que esta pantalla refleja.
    ///   - onOpenCards: salta a la pestaña Tarjetas (guía de Apple Pay).
    ///   - onOpenSystemSettings: abre los Ajustes del sistema en la página de
    ///     Lana, para conceder el permiso de dictado.
    public init(
        model: SettingsModel,
        onOpenCards: (() -> Void)? = nil,
        onOpenSystemSettings: (() -> Void)? = nil) {
        self.model = model
        self.onOpenCards = onOpenCards
        self.onOpenSystemSettings = onOpenSystemSettings
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg.rawValue) {
                    lanaSection
                    appearanceSection
                    dataSection
                    aboutSection
                }
                .padding(Space.md.rawValue)
                // El micrófono flotante de `MainTabView` se monta sobre esta
                // pantalla y tapaba la fila de Versión.
                .floatingMicClearance()
            }
            .background(lana.surface)
            .navigationTitle("Ajustes")
            .task { await model.onAppear() }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .lanaInfo: LanaInfoView(onOpenCards: onOpenCards)
                case .lanaLearning: LanaLearningView(model: model)
                case .theme: ThemeSettingsView(model: model)
                case .data: DataSettingsView(model: model)
                case .privacy: PrivacyView()
                case .aboutLana: AboutLanaView()
                }
            }
        }
    }

    // MARK: - LANA

    private var lanaSection: some View {
        section("Lana") {
            LanaCard {
                VStack(spacing: 0) {
                    NavigationLink(value: SettingsDestination.lanaInfo) {
                        SettingsRow(
                            icon: "sparkles",
                            title: "Cómo funciona Lana",
                            subtitle: "Tu asistente financiero")
                    }
                    .buttonStyle(.plain)

                    rowDivider

                    NavigationLink(value: SettingsDestination.lanaLearning) {
                        SettingsRow(
                            icon: "brain",
                            title: "Aprendizaje",
                            subtitle: learnedWordsSubtitle)
                    }
                    .buttonStyle(.plain)

                    if let availability = model.speechAvailability {
                        rowDivider
                        speechRow(availability)
                    }
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

    /// El permiso de dictado, visible antes de necesitarlo — hasta ahora solo
    /// aparecía dentro de la hoja de captura, y ya fallando. Solo es tocable
    /// cuando hay algo que hacer (permiso negado o restringido); un permiso
    /// concedido es un dato, no una acción, y no lleva chevron a ningún lado.
    @ViewBuilder
    private func speechRow(_ availability: SpeechAvailability) -> some View {
        let row = SettingsRow(
            icon: "mic",
            title: "Micrófono y dictado",
            subtitle: speechSubtitle(availability),
            showsChevron: isSpeechActionable(availability))

        if isSpeechActionable(availability), let onOpenSystemSettings {
            Button(action: onOpenSystemSettings) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    /// Hay algo que el usuario pueda arreglar desde los Ajustes del sistema.
    private func isSpeechActionable(_ availability: SpeechAvailability) -> Bool {
        availability == .permissionDenied || availability == .restricted
    }

    /// El tono es "dato con su salida al lado", nunca reproche: no haber dado
    /// permiso no es un error del usuario (Docs/CLAUDE.md → Tono del producto).
    private func speechSubtitle(_ availability: SpeechAvailability) -> String {
        switch availability {
        case .available: "Permitido"
        case .permissionNotDetermined: "Se pide la primera vez que uses el micrófono"
        case .permissionDenied: "Sin permiso — actívalo en Ajustes"
        case .restricted: "Restringido en este dispositivo"
        case .unavailable: "El dictado no está disponible en este idioma"
        }
    }

    // MARK: - APARIENCIA

    private var appearanceSection: some View {
        section("Apariencia") {
            LanaCard {
                NavigationLink(value: SettingsDestination.theme) {
                    SettingsRow(
                        icon: "paintpalette",
                        title: "Tema",
                        subtitle: model.selectedThemeName)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - DATOS

    private var dataSection: some View {
        section("Datos") {
            LanaCard {
                NavigationLink(value: SettingsDestination.data) {
                    SettingsRow(
                        icon: "icloud",
                        title: "iCloud",
                        subtitle: syncSummary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Resumen compacto del estado de sync para la fila principal — el
    /// detalle largo (y el caso `.failed` completo) vive en `DataSettingsView`.
    private var syncSummary: String {
        switch model.syncStatus {
        case .disabled: "Solo en este dispositivo"
        case .syncing: "Sincronizando…"
        case let .synced(lastSuccess): "Sincronizado \(lastSuccess.formatted(.relative(presentation: .named)))"
        case .failed: "No se pudo respaldar la última vez"
        }
    }

    // MARK: - ACERCA DE

    private var aboutSection: some View {
        section("Acerca de") {
            LanaCard {
                VStack(spacing: 0) {
                    NavigationLink(value: SettingsDestination.privacy) {
                        SettingsRow(icon: "lock", title: "Privacidad", subtitle: nil)
                    }
                    .buttonStyle(.plain)

                    rowDivider

                    NavigationLink(value: SettingsDestination.aboutLana) {
                        SettingsRow(icon: "info.circle", title: "Acerca de Lana", subtitle: nil)
                    }
                    .buttonStyle(.plain)

                    if let version = model.appVersion {
                        rowDivider
                        SettingsRow(
                            icon: "number",
                            title: "Versión",
                            subtitle: version,
                            showsChevron: false)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// El separador entre filas, alineado con el texto y no con el borde de la
    /// tarjeta: arranca donde termina la columna del icono (su ancho más su
    /// espaciado), como cualquier lista agrupada de iOS.
    private var rowDivider: some View {
        Divider()
            .padding(.leading, SettingsRow.iconColumnWidth + Space.md.rawValue)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            Text(title.uppercased())
                .lanaFont(.caption)
                .foregroundStyle(lana.textSecondary)
            content()
        }
    }
}

/// Destinos empujables desde Ajustes. Un solo enum para todo el stack de la
/// pantalla (mismo patrón que `DashboardDestination`), así una fila anidada
/// —p. ej. Privacidad dentro de "Acerca de"— navega en el mismo stack.
enum SettingsDestination: Hashable {
    case lanaInfo
    case lanaLearning
    case theme
    case data
    case privacy
    case aboutLana
}

/// Una fila de Ajustes: icono con el acento del tema, título, subtítulo
/// opcional y chevron. El lenguaje visual único de las listas de Ajustes —
/// para no repetir el mismo `HStack` en cada sección.
struct SettingsRow: View {
    @Environment(\.lana) private var lana
    let icon: String
    let title: String
    let subtitle: String?
    var showsChevron = true

    /// El ancho de la columna del icono. Público dentro del módulo porque los
    /// separadores se alinean con el texto, no con el borde de la tarjeta.
    static let iconColumnWidth = Space.lg.rawValue

    /// El mínimo que exigen las Human Interface Guidelines para algo tocable.
    /// No es un valor de espaciado (por eso no sale de `Space`): es el tamaño
    /// del dedo. Sin esto, una fila de una sola línea medía ~28pt.
    private static let minimumTouchTarget: CGFloat = 44

    var body: some View {
        HStack(spacing: Space.md.rawValue) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(lana.accent)
                .frame(width: Self.iconColumnWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lanaFont(.body)
                    .foregroundStyle(lana.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.textSecondary)
                }
            }

            Spacer(minLength: Space.sm.rawValue)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.textSecondary)
            }
        }
        .padding(.vertical, Space.xs.rawValue)
        .frame(minHeight: Self.minimumTouchTarget)
        .contentShape(Rectangle())
        // Una sola parada de VoiceOver por fila: sin esto se recorre el icono,
        // el título y el subtítulo como tres elementos sueltos.
        .accessibilityElement(children: .combine)
    }
}

extension String {
    /// Si es una de las categorías cerradas, su índice ya es único por
    /// construcción (`SuggestedCategory.rampIndex`). Si no, cae a un hash
    /// estable (djb2) — el `Hashable` de Swift cambia de semilla en cada
    /// corrida del proceso y no sirve para esto. El módulo (12) tiene que
    /// coincidir con `LanaColors.categoryRamp.count`. Copia local: la misma
    /// idea vive en `DashboardFeature`/`CardsFeature`, y las features no se
    /// importan entre sí.
    var stableRampIndex: Int {
        if let known = SuggestedCategory(rawValue: self) {
            return known.rampIndex
        }
        var hash = 5381
        for scalar in unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash) % 12
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        SettingsView(
            model: SettingsModel(
                vocabularyStore: InMemoryCorrectionVocabularyStore(seed: [
                    CorrectionEntry(term: "bocina", category: "ocio", useCount: 4),
                    CorrectionEntry(term: "chicles", category: "despensa", useCount: 7)
                ]),
                syncStatusReporting: InMemorySyncStatusReporting(.synced(lastSuccess: .now)),
                speech: InMemorySpeechTranscribing(),
                userDefaults: UserDefaults(suiteName: "preview") ?? .standard),
            onOpenCards: {},
            onOpenSystemSettings: {})
            .lanaTheme(theme)
    }
}

import LanaCore
import LanaDesign
import SwiftUI

/// La `Guia_ApplePay` (ADR-0009): hospeda la pantalla actual según
/// `model.currentScreen` y los controles de navegación ("Atrás", "Siguiente",
/// "Omitir" y, en cierre, "Confirmar"). Sin lógica propia — refleja
/// `GuiaApplePayModel` y llama a sus métodos y a los handlers inyectados
/// (Docs/ARCHITECTURE.md, Docs/CONVENTIONS.md).
///
/// Los handlers `onOpenCardSettings` y `onOpenShortcutsApp` cruzan fronteras de
/// feature (Ajustes → Tarjetas y la app Atajos), así que `ContentView` los
/// inyecta: las features nunca se importan entre sí.
public struct GuiaApplePayView: View {
    @Environment(\.lana) private var lana
    @State private var model: GuiaApplePayModel

    /// Abre Ajustes → Tarjetas para editar los datos de emparejamiento (R3.4).
    private let onOpenCardSettings: () -> Void
    /// Abre la app Atajos (best-effort); `nil` cuando el contenedor no lo
    /// cablea — la guía funciona igual sin él.
    private let onOpenShortcutsApp: (() -> Void)?

    /// - Parameters:
    ///   - model: la máquina de estados y el contenido de la guía.
    ///   - onOpenCardSettings: abre Ajustes → Tarjetas (R3.4), inyectado por
    ///     `ContentView` porque cruza fronteras de feature.
    ///   - onOpenShortcutsApp: abre la app Atajos, best-effort (opcional).
    public init(
        model: GuiaApplePayModel,
        onOpenCardSettings: @escaping () -> Void,
        onOpenShortcutsApp: (() -> Void)? = nil) {
        _model = State(initialValue: model)
        self.onOpenCardSettings = onOpenCardSettings
        self.onOpenShortcutsApp = onOpenShortcutsApp
    }

    /// Ancla al inicio del contenido para regresar el scroll arriba al cambiar
    /// de pantalla — sin esto, avanzar desde el fondo de una pantalla larga (los
    /// 6 pasos de Atajos) dejaba la siguiente empezando a media página, no en
    /// su título.
    private enum ScrollAnchor { case top }

    public var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    currentScreen
                        .padding(Space.md.rawValue)
                        .id(ScrollAnchor.top)
                }
                .onChange(of: model.currentScreen) { _, _ in
                    // Al inicio de la nueva pantalla, no donde quedó la anterior.
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
            navigationBar
        }
        .background(lana.surface)
        .onAppear { model.presentFirstScreen() }
    }

    // MARK: - Encabezado

    /// Título y progreso. Son cinco pantallas, una de ellas larga, y la barra
    /// de abajo solo decía "Siguiente": no había forma de saber si faltaba un
    /// paso o cuatro. Como hoja (`Mode.standalone`) es además el único título
    /// que tiene la pantalla. El progreso va en texto, no en puntitos: la
    /// forma y el color nunca son el único portador (Docs/CONVENTIONS.md).
    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            Text("Configurar Apple Pay")
                .lanaFont(.headline)
                .foregroundStyle(lana.textPrimary)
            Text(progressText)
                .lanaFont(.caption)
                .foregroundStyle(lana.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md.rawValue)
        .background(lana.surfaceRaised)
        .accessibilityElement(children: .combine)
    }

    private var progressText: String {
        "Paso \(model.currentScreen.rawValue + 1) de \(GuiaApplePayModel.Screen.allCases.count)"
    }

    @ViewBuilder
    private var currentScreen: some View {
        if let content = model.content {
            switch model.currentScreen {
            case .requirements:
                RequirementsStepView(
                    requirement: content.deviceRequirement,
                    isRunningInSimulator: model.isRunningInSimulator)
            case .shortcutSteps:
                // R2.6: si el disparador Wallet o la app Atajos no están
                // disponibles, no ofrecemos armar la automatización — mostramos
                // la incompatibilidad y la condición requerida.
                if model.isAutomationAvailable {
                    ShortcutStepsView(
                        steps: content.shortcutSteps,
                        parameterMappings: content.parameterMappings,
                        onOpenShortcutsApp: onOpenShortcutsApp)
                } else {
                    automationUnavailableState
                }
            case .matching:
                MatchingStepView(
                    matching: content.matching,
                    onOpenCardSettings: onOpenCardSettings)
            case .limitations:
                LimitationsStepView(limitations: content.limitations)
            case .closing:
                closingScreen
            }
        } else {
            // R1.5: no se pudo cargar el contenido — mostramos el error con la
            // opción de reintentar, sin cambiar de pantalla del onboarding.
            presentationErrorState
        }
    }

    // MARK: - Estados de error (EmptyStateView de LanaDesign)

    /// R1.5 — no se pudo mostrar la primera pantalla. Ofrece "Reintentar" que
    /// llama `model.retryPresentation()`. El ícono + texto portan la
    /// información, nunca solo el color (Docs/CONVENTIONS.md).
    private var presentationErrorState: some View {
        EmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: "No se pudo cargar la guía",
            message: model.presentationError
                ?? GuiaApplePayError.contentUnavailable.errorDescription,
            actionTitle: "Reintentar",
            action: { model.retryPresentation() })
    }

    /// R2.6 — el dispositivo no puede crear la automatización porque falta la
    /// app Atajos o el disparador de Wallet. No ofrece armar la automatización;
    /// solo describe la incompatibilidad y la condición requerida.
    private var automationUnavailableState: some View {
        EmptyStateView(
            systemImage: "square.stack.3d.up.slash",
            title: "No se puede crear la automatización",
            message: GuiaApplePayError.automationUnsupported.errorDescription)
    }

    /// Pantalla de cierre (R6). Muestra el resumen y, si el avance del
    /// onboarding falló tras confirmar (R6.4), añade el error con "Reintentar"
    /// → `model.retryAdvance()`, conservando el resumen. El control de confirmar
    /// vive en `navigationBar` y sigue disponible aun con `summaryUnavailable`
    /// (R6.2).
    private var closingScreen: some View {
        VStack(spacing: Space.md.rawValue) {
            ClosingStepView(
                summary: model.completionSummary,
                summaryUnavailable: model.summaryUnavailable,
                mode: model.mode)

            if let advanceError = model.advanceError {
                EmptyStateView(
                    systemImage: "exclamationmark.arrow.circlepath",
                    title: "No se pudo continuar",
                    message: advanceError,
                    actionTitle: "Reintentar",
                    action: { Task { await model.retryAdvance() } })
            }
        }
    }

    // MARK: - Controles de navegación

    private var navigationBar: some View {
        HStack(spacing: Space.sm.rawValue) {
            if model.currentScreen != .requirements {
                Button("Atrás") { model.back() }
                    .foregroundStyle(lana.textSecondary)
            }

            Spacer()

            if model.currentScreen != .closing {
                Button(skipTitle) { model.skip() }
                    .foregroundStyle(lana.textSecondary)
            }

            if model.currentScreen == .closing {
                Button(confirmTitle) {
                    Task { await model.confirmCompletion() }
                }
                .buttonStyle(.borderedProminent)
                .tint(lana.accent)
            } else {
                Button("Siguiente") { model.next() }
                    .buttonStyle(.borderedProminent)
                    .tint(lana.accent)
            }
        }
        .lanaFont(.body)
        .padding(Space.md.rawValue)
        .background(lana.surfaceRaised)
    }

    /// Salirse de la guía. En onboarding es "Omitir" —hay un flujo del que te
    /// estás saltando un paso—; reabierta desde Tarjetas no se omite nada, se
    /// cierra la hoja, y llamarlo "Omitir" describe algo que no pasa.
    private var skipTitle: String {
        switch model.mode {
        case .onboarding: "Omitir"
        case .standalone: "Cerrar"
        }
    }

    /// Lo mismo en el cierre: en `standalone` `confirmCompletion()` solo cierra
    /// la hoja, no confirma nada ante nadie.
    private var confirmTitle: String {
        switch model.mode {
        case .onboarding: "Confirmar"
        case .standalone: "Listo"
        }
    }
}

#Preview("Flujo normal") {
    ForEach(LanaTheme.allCases) { theme in
        GuiaApplePayView(
            model: GuiaApplePayModel(
                mode: .onboarding,
                content: .standard,
                environment: InMemoryApplePayEnvironment()),
            onOpenCardSettings: {},
            onOpenShortcutsApp: {})
            .lanaTheme(theme)
    }
}

#Preview("Error de presentación (R1.5)") {
    ForEach(LanaTheme.allCases) { theme in
        GuiaApplePayView(
            model: GuiaApplePayModel(
                mode: .onboarding,
                content: nil,
                environment: InMemoryApplePayEnvironment()),
            onOpenCardSettings: {},
            onOpenShortcutsApp: {})
            .lanaTheme(theme)
    }
}

#Preview("Atajos no disponible (R2.6)") {
    ForEach(LanaTheme.allCases) { theme in
        GuiaApplePayView(
            model: GuiaApplePayModel(
                mode: .onboarding,
                content: .standard,
                environment: InMemoryApplePayEnvironment(isShortcutsAutomationAvailable: false)),
            onOpenCardSettings: {},
            onOpenShortcutsApp: {})
            .lanaTheme(theme)
    }
}

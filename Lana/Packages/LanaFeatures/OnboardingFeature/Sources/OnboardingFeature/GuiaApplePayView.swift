import LanaCore
import LanaDesign
import SwiftUI

/// La guía de Apple Pay (ADR-0009; rediseño, sección 13): cuatro pasos para
/// armar la automatización de Atajos que registra los pagos por contacto.
///
/// Es lo más difícil de la app —pide salir a otra aplicación y conectar
/// campos— así que el paso difícil se muestra como un mapeo visual y no como
/// prosa. **Siempre se puede omitir.**
///
/// Los cuatro pasos cuentan configuración, no pantallas: el cierre confirma el
/// último paso. La máquina de estados conserva sus cinco pantallas
/// (`GuiaApplePayModel.Screen`), que es lo que sus tests fijan.
public struct GuiaApplePayView: View {
    @Environment(\.lana) private var lana
    @State private var model: GuiaApplePayModel

    /// Abre Ajustes → Tarjetas para editar los datos de emparejamiento (R3.4).
    private let onOpenCardSettings: () -> Void
    /// Abre la app Atajos (best-effort); `nil` cuando no se cablea.
    private let onOpenShortcutsApp: (() -> Void)?

    /// Cuántos pasos ve la persona. El cierre no cuenta: es la confirmación
    /// del último, no un trámite más.
    private static var totalSteps: Int {
        4
    }

    public init(
        model: GuiaApplePayModel,
        onOpenCardSettings: @escaping () -> Void,
        onOpenShortcutsApp: (() -> Void)? = nil) {
        _model = State(initialValue: model)
        self.onOpenCardSettings = onOpenCardSettings
        self.onOpenShortcutsApp = onOpenShortcutsApp
    }

    /// Ancla al inicio del contenido: avanzar desde el fondo de un paso largo
    /// dejaba el siguiente empezando a media página.
    private enum ScrollAnchor { case top }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    stepContent
                        .padding(.horizontal, LanaMetrics.onboardingMargin)
                        .padding(.top, LanaMetrics.contentTopWithHeader)
                        .padding(.bottom, Space.xl.rawValue)
                        .id(ScrollAnchor.top)
                }
                .onChange(of: model.currentScreen) { _, _ in
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
            footer
        }
        .background(lana.bg)
        .onAppear { model.presentFirstScreen() }
    }

    // MARK: - Los cuatro pasos

    @ViewBuilder
    private var stepContent: some View {
        if let content = model.content {
            switch model.currentScreen {
            case .requirements:
                GuideStepChrome(
                    step: 1,
                    totalSteps: Self.totalSteps,
                    title: "Qué vas a lograr",
                    message: """
                    Que tus pagos con Apple Pay se registren solos. Necesitas la app Atajos y \
                    tus tarjetas dadas de alta en Lana.
                    """,
                    onSkip: { model.skip() },
                    content: {
                        VStack(alignment: .leading, spacing: Space.md.rawValue) {
                            RequirementsStepView(
                                requirement: content.deviceRequirement,
                                isRunningInSimulator: model.isRunningInSimulator)
                            Button("Ir a Tarjetas", action: onOpenCardSettings)
                                .buttonStyle(.lana(.secondary))
                        }
                    })
            case .shortcutSteps:
                GuideStepChrome(
                    step: 2,
                    totalSteps: Self.totalSteps,
                    title: "Conecta Wallet con tus tarjetas",
                    message: """
                    En la app Atajos vas a crear una automatización. Lana necesita que conectes \
                    estos campos:
                    """,
                    onSkip: { model.skip() },
                    content: {
                        mappingStep(content)
                    })
            case .matching:
                GuideStepChrome(
                    step: 3,
                    totalSteps: Self.totalSteps,
                    title: "Crea la automatización",
                    message: nil,
                    onSkip: { model.skip() },
                    content: {
                        automationStep(content)
                    })
            case .limitations, .closing:
                GuideStepChrome(
                    step: 4,
                    totalSteps: Self.totalSteps,
                    title: "Qué esperar",
                    message: nil,
                    onSkip: { model.skip() },
                    content: {
                        expectationsStep(content)
                    })
            }
        } else {
            // R1.5: no se pudo cargar el contenido.
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "No se pudo cargar la guía",
                message: model.presentationError ?? GuiaApplePayError.contentUnavailable.errorDescription,
                actionTitle: "Reintentar",
                action: { model.retryPresentation() })
        }
    }

    /// El paso donde más gente se atora: los campos que hay que conectar, como
    /// correspondencia y no como prosa.
    private func mappingStep(_ content: GuiaApplePayContent) -> some View {
        VStack(alignment: .leading, spacing: Space.p10.rawValue) {
            ForEach(content.parameterMappings) { mapping in
                MappingRow(walletLabel: mapping.walletLabel, lanaLabel: mapping.intentLabel)
            }

            GuideWarning(
                text: """
                Funciona solo con pagos por contacto, no con compras en el navegador. Puede tardar \
                unos segundos y todo lo capturado queda
                """,
                emphasis: "por revisar.")
                .padding(.top, Space.md.rawValue)

            MatchingStepView(matching: content.matching, onOpenCardSettings: onOpenCardSettings)
                .padding(.top, Space.md.rawValue)
        }
    }

    /// R2.6: si el disparador de Wallet o la app Atajos no están, no se ofrece
    /// armar nada — se explica por qué y se puede seguir sin Apple Pay.
    @ViewBuilder
    private func automationStep(_ content: GuiaApplePayContent) -> some View {
        if model.isAutomationAvailable {
            ShortcutStepsView(
                steps: content.shortcutSteps,
                parameterMappings: content.parameterMappings,
                onOpenShortcutsApp: onOpenShortcutsApp)
        } else {
            EmptyStateView(
                systemImage: "square.stack.3d.up.slash",
                title: "No se puede crear la automatización",
                message: GuiaApplePayError.automationUnsupported.errorDescription)
        }
    }

    /// Honesto: solo pagos por contacto, puede tardar, a veces se dispara con
    /// rechazadas, y hay que revisar cada uno.
    private func expectationsStep(_ content: GuiaApplePayContent) -> some View {
        VStack(alignment: .leading, spacing: Space.md.rawValue) {
            LimitationsStepView(limitations: content.limitations)

            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    Text("¿Cómo saber si quedó bien?")
                        .lanaFont(.bodyEmphasis)
                        .foregroundStyle(lana.ink)
                    Text("""
                    Haz un pago pequeño por contacto y revisa la bandeja "Por revisar" en Hoy. \
                    Si aparece ahí, la automatización está corriendo.
                    """)
                    .lanaFont(.explanation)
                    .foregroundStyle(lana.ink70)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

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

    // MARK: - Pie fijo

    /// El botón principal y la salida, siempre a la mano.
    private var footer: some View {
        VStack(spacing: Space.p14.rawValue) {
            Button(primaryTitle) {
                if isLastStep {
                    Task { await model.confirmCompletion() }
                } else {
                    model.next()
                }
            }
            .buttonStyle(.lana(size: .large, isExpanded: true))

            Button(secondaryTitle) { model.skip() }
                .lanaFont(.bodyEmphasis)
                .foregroundStyle(lana.ink50)
                .buttonStyle(.plain)
                .frame(minHeight: LanaMetrics.minTouchTarget)
        }
        .padding(.horizontal, LanaMetrics.screenMargin)
        .padding(.bottom, Space.p44.rawValue)
        .padding(.top, Space.md.rawValue)
        .background(lana.bg)
    }

    /// Límites y cierre son el mismo paso para quien la usa.
    private var isLastStep: Bool {
        model.currentScreen == .limitations || model.currentScreen == .closing
    }

    private var primaryTitle: String {
        if isLastStep {
            return model.mode == .onboarding ? "Listo, ya la creé" : "Listo"
        }
        return model.currentScreen == .matching ? "Abrir la app Atajos" : "Siguiente"
    }

    /// En onboarding se omite un paso del flujo; reabierta desde Tarjetas no se
    /// omite nada, se cierra.
    private var secondaryTitle: String {
        model.mode == .onboarding ? "Lo hago después" : "Cerrar"
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

#Preview("Atajos no disponible (R2.6)") {
    GuiaApplePayView(
        model: GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment(isShortcutsAutomationAvailable: false)),
        onOpenCardSettings: {},
        onOpenShortcutsApp: {})
        .lanaTheme(.zafiro)
}

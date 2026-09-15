import LanaCore
import LanaDesign
import SwiftUI

/// El contenedor del onboarding de primer arranque (ADR-0009). Presenta el paso
/// actual de `OnboardingModel` y, en el paso de la guía, hospeda
/// `GuiaApplePayView` en `Mode.onboarding`. Sin lógica propia — refleja el
/// modelo y le pasa los handlers que cruzan fronteras de feature
/// (Docs/ARCHITECTURE.md, Docs/CONVENTIONS.md).
///
/// Los handlers `onOpenCardSettings` y `onOpenShortcutsApp` los recibe de
/// `ContentView` y los pasa hacia abajo a `GuiaApplePayView`: las features nunca
/// se importan entre sí, solo `ContentView` conoce `CardsFeature` y la app
/// Atajos.
public struct OnboardingView: View {
    @Environment(\.lana) private var lana
    @State private var model: OnboardingModel
    /// La máquina de estados de la guía del paso actual. Vive como estado de la
    /// vista para poder observar cuándo la guía se omite (`isFinished` sin haber
    /// avanzado el onboarding) y avanzar entonces el propio paso (R1.3).
    @State private var guideModel: GuiaApplePayModel

    /// El entorno para construir el `GuiaApplePayModel` de la guía (R2.6, R5.2).
    private let environment: any ApplePayEnvironmentProbing
    /// Abre Ajustes → Tarjetas para editar los datos de emparejamiento (R3.4).
    private let onOpenCardSettings: () -> Void
    /// Abre la app Atajos (best-effort); `nil` cuando el contenedor no lo cablea.
    private let onOpenShortcutsApp: (() -> Void)?

    /// - Parameters:
    ///   - model: los pasos del onboarding y su avance (R1.3, R6.3).
    ///   - environment: consulta si la automatización es posible (R2.6) y si
    ///     corre en simulador (R5.2); se usa para construir el modelo de la guía.
    ///   - onOpenCardSettings: abre Ajustes → Tarjetas (R3.4), inyectado por
    ///     `ContentView` porque cruza fronteras de feature.
    ///   - onOpenShortcutsApp: abre la app Atajos, best-effort (opcional).
    public init(
        model: OnboardingModel,
        environment: any ApplePayEnvironmentProbing,
        onOpenCardSettings: @escaping () -> Void,
        onOpenShortcutsApp: (() -> Void)? = nil) {
        _model = State(initialValue: model)
        self.environment = environment
        self.onOpenCardSettings = onOpenCardSettings
        self.onOpenShortcutsApp = onOpenShortcutsApp
        // La guía en `Mode.onboarding` avanza el onboarding al confirmar su
        // cierre (R6.3); un fallo se propaga para "Reintentar" (R6.4).
        _guideModel = State(initialValue: GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: environment,
            onOnboardingFinished: { await model.finishCurrentStep() }))
    }

    public var body: some View {
        Group {
            switch model.currentStep {
            case .applePayGuide:
                applePayGuideStep
            case nil:
                // El onboarding terminó; `ContentView` ya transicionó a
                // `MainTabView`. No queda nada que mostrar aquí.
                Color.clear
            }
        }
        .background(lana.bg)
    }

    /// El paso de la guía de Apple Pay: hospeda `GuiaApplePayView` en
    /// `Mode.onboarding`. Al confirmar el cierre, la guía completa el onboarding
    /// vía su handler `onOnboardingFinished` (R6.3/R6.4). Al omitir, la guía
    /// marca `isFinished` sin cerrar el flujo; esta vista lo observa y avanza el
    /// propio paso del onboarding (R1.3).
    private var applePayGuideStep: some View {
        GuiaApplePayView(
            model: guideModel,
            onOpenCardSettings: onOpenCardSettings,
            onOpenShortcutsApp: onOpenShortcutsApp)
            .onChange(of: guideModel.isFinished) { _, isFinished in
                // La guía terminó. Distinguimos por la pantalla en que quedó:
                // "Omitir" solo se ofrece fuera del cierre, así que si la guía
                // terminó sin estar en `.closing`, fue una omisión → avanzamos el
                // paso del onboarding sin cerrar el flujo (R1.3). En el cierre, el
                // avance ya lo hizo el handler `onOnboardingFinished` (R6.3), así
                // que aquí no hacemos nada para no avanzar dos veces.
                guard isFinished, guideModel.currentScreen != .closing else { return }
                model.skipCurrentStep()
            }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        OnboardingView(
            model: OnboardingModel(onOnboardingFinished: { true }),
            environment: InMemoryApplePayEnvironment(),
            onOpenCardSettings: {},
            onOpenShortcutsApp: {})
            .lanaTheme(theme)
    }
}

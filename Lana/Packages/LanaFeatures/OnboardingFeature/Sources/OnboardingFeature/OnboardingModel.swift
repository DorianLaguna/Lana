import Foundation
import LanaCore
import Observation

/// El contenedor del flujo de onboarding de primer arranque (ADR-0009). Presenta
/// una secuencia extensible de pasos; al menos uno es el punto de entrada
/// visible y etiquetado a la `Guia_ApplePay` (R1.1). El modelo decide — la vista
/// (`OnboardingView`) solo refleja este estado y llama a sus métodos
/// (Docs/ARCHITECTURE.md, Docs/CONVENTIONS.md).
///
/// El onboarding general de Lana no existe hoy; este contenedor es el mínimo
/// necesario para hospedar la guía y su punto de entrada. Los demás pasos quedan
/// como un arreglo extensible (`steps`), pero su contenido no es parte de esta
/// funcionalidad (Docs/DESIGN → nota de alcance).
@MainActor
@Observable
public final class OnboardingModel {
    /// Un paso del onboarding. Es un arreglo extensible: hoy solo existe el
    /// punto de entrada a la guía, pero la máquina de pasos ya soporta más.
    public enum Step: Sendable, Equatable, Identifiable {
        /// El punto de entrada visible y etiquetado "Configurar Apple Pay"
        /// (R1.1). Al seleccionarlo se presenta la guía dentro del onboarding.
        case applePayGuide

        public var id: String {
            switch self {
            case .applePayGuide: "applePayGuide"
            }
        }

        /// La etiqueta visible del paso — nunca vive hardcodeada en la vista.
        /// El punto de entrada de la guía se etiqueta exactamente "Configurar
        /// Apple Pay" (R1.1).
        public var title: String {
            switch self {
            case .applePayGuide: "Configurar Apple Pay"
            }
        }
    }

    /// Los pasos del onboarding, en orden. Inmutable tras construir; siempre
    /// incluye el punto de entrada a la guía (R1.1).
    public let steps: [Step]

    /// Handler inyectado por `ContentView` para marcar el onboarding completo y
    /// transicionar a `MainTabView` al confirmar la guía (R6.3). Devuelve `true`
    /// si el avance se completó; `false` deja la guía en el cierre para
    /// reintentar (R6.4).
    private let onOnboardingFinished: () async -> Bool

    /// El índice del paso actual, dentro de `[0, steps.count)`.
    public private(set) var currentStepIndex: Int

    /// `true` cuando el onboarding completo terminó (confirmó el último paso).
    public private(set) var isFinished: Bool

    /// - Parameters:
    ///   - steps: los pasos del onboarding; por defecto solo el punto de entrada
    ///     a la guía (R1.1). El arreglo es extensible para futuros pasos.
    ///   - onOnboardingFinished: handler que `ContentView` inyecta para fijar la
    ///     bandera de onboarding completado y entrar a `MainTabView` (R6.3);
    ///     devolver `false` señala que el avance falló (R6.4).
    public init(
        steps: [Step] = [.applePayGuide],
        onOnboardingFinished: @escaping () async -> Bool) {
        self.steps = steps
        self.onOnboardingFinished = onOnboardingFinished
        currentStepIndex = 0
        isFinished = false
    }

    /// El paso que se está mostrando ahora, o `nil` si el onboarding terminó y
    /// no queda ningún paso por delante.
    public var currentStep: Step? {
        steps.indices.contains(currentStepIndex) ? steps[currentStepIndex] : nil
    }

    /// Omitir el paso actual del onboarding (R1.3). Avanza al siguiente paso sin
    /// activar la captura de Apple Pay y **sin cerrar** el flujo de onboarding:
    /// si aún quedan pasos, solo mueve el índice; si era el último, el flujo se
    /// da por terminado igual que al confirmar.
    ///
    /// La guía en sí también se omite por su cuenta (`GuiaApplePayModel.skip()`),
    /// pero es este contenedor quien decide qué hacer con el paso del onboarding
    /// — la guía nunca cierra el flujo (Docs/DESIGN).
    public func skipCurrentStep() {
        advanceStep()
    }

    /// Avanza el onboarding tras confirmar la guía en su pantalla de cierre
    /// (R6.3). Si aún quedan pasos por delante, solo mueve el índice; si era el
    /// último paso, invoca `onOnboardingFinished` para marcar el onboarding
    /// completo y entrar a `MainTabView`.
    ///
    /// - Returns: `true` si el flujo avanzó (o se completó); `false` si el
    ///   avance final falló y el llamador debe conservar el cierre para
    ///   reintentar (R6.4).
    @discardableResult
    public func finishCurrentStep() async -> Bool {
        // Si no es el último paso, avanzar dentro del onboarding no puede fallar.
        if currentStepIndex < steps.count - 1 {
            advanceStep()
            return true
        }
        // Último paso: pedir a `ContentView` que complete el onboarding (R6.3).
        // Un fallo se propaga para que la guía muestre "Reintentar" (R6.4).
        let finished = await onOnboardingFinished()
        if finished {
            isFinished = true
        }
        return finished
    }

    /// Mueve el índice al siguiente paso sin cerrar el flujo; si ya no quedan
    /// pasos, marca el onboarding como terminado.
    private func advanceStep() {
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        } else {
            isFinished = true
        }
    }
}

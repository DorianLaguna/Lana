import Foundation
import LanaCore
import Observation

/// Toda la lógica de navegación y estado de la `Guia_ApplePay` (ADR-0009). El
/// modelo decide — la vista solo refleja este estado y llama a sus métodos
/// (Docs/ARCHITECTURE.md, Docs/CONVENTIONS.md).
///
/// Este archivo define el **esqueleto de estado**: los tipos anidados
/// (`Mode`, `Screen`, `CompletionStep`), las propiedades observadas y el
/// inicializador. La máquina de estados de navegación (`presentFirstScreen`,
/// `next`, `back`, `skip`, `retryPresentation`), el resumen de cierre
/// (`completionSummary`) y la finalización (`confirmCompletion`,
/// `retryAdvance`) se implementan en tareas posteriores.
@MainActor
@Observable
public final class GuiaApplePayModel {
    /// Cómo termina la guía: avanzando el onboarding o cerrando la hoja
    /// (post-onboarding, R1.4).
    public enum Mode: Sendable {
        /// Presentada dentro del onboarding — al confirmar, avanza el flujo.
        case onboarding
        /// Reabierta desde Ajustes — al confirmar, solo cierra la hoja (R1.4).
        case standalone
    }

    /// Las pantallas de la guía, en orden. El `rawValue` es el índice de la
    /// máquina de estados; la lista es inmutable tras construir.
    public enum Screen: Int, CaseIterable, Sendable {
        /// Requisitos de dispositivo físico + limitación del simulador. SIEMPRE
        /// primero, antes de cualquier paso de configuración (R5.3).
        case requirements
        /// Pasos numerados para armar la automatización de Atajos (R2).
        case shortcutSteps
        /// Explicación del emparejamiento de tarjetas (R3).
        case matching
        /// Limitaciones conocidas de la captura automática (R4).
        case limitations
        /// Pantalla de cierre con el resumen de pasos completados (R6).
        case closing
    }

    /// Un paso del resumen de cierre, con su indicador de estado (R6.1).
    public struct CompletionStep: Sendable, Equatable, Identifiable {
        public let id: Int
        public let title: String
        public let isCompleted: Bool

        public init(id: Int, title: String, isCompleted: Bool) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
        }
    }

    /// El modo con el que se presentó la guía — decide qué pasa al confirmar.
    public let mode: Mode

    /// Handler inyectado por el contenedor (`ContentView` en `Mode.onboarding`,
    /// la hoja de Ajustes en `Mode.standalone`) para avanzar el flujo al
    /// confirmar la finalización (R6.3). Devuelve `true` si el avance se
    /// completó; `false` señala que falló y el modelo conserva el cierre para
    /// reintentar (R6.4). Es opcional: en `Mode.standalone` puede no cablearse
    /// (el cierre de la hoja lo maneja la propia vista al ver `isFinished`).
    private let onOnboardingFinished: (() async -> Bool)?

    /// La pantalla actual de la máquina de estados de navegación.
    public private(set) var currentScreen: Screen
    /// El contenido estático de la guía; `nil` si no se pudo cargar (R1.5).
    public private(set) var content: GuiaApplePayContent?
    /// Mensaje cuando no se puede mostrar la primera pantalla (R1.5).
    public private(set) var presentationError: String?
    /// `true` cuando el resumen de cierre no está disponible (R6.2).
    public private(set) var summaryUnavailable: Bool
    /// Mensaje cuando el avance del onboarding falla tras confirmar (R6.4).
    public private(set) var advanceError: String?
    /// `true` cuando la guía terminó (por omitir o por confirmar).
    public private(set) var isFinished: Bool

    /// `false` cuando el disparador de Wallet o la app Atajos no están
    /// disponibles en el dispositivo (R2.6). Poblado desde el entorno inyectado.
    public private(set) var isAutomationAvailable: Bool
    /// `true` cuando corre en el simulador de iOS (R5.2). Poblado desde el
    /// entorno inyectado.
    public private(set) var isRunningInSimulator: Bool

    /// - Parameters:
    ///   - mode: dentro del onboarding o reabierta desde Ajustes (R1.4).
    ///   - content: el contenido estático de la guía; `nil` simula el fallo de
    ///     carga que exige R1.5.
    ///   - environment: consulta si la automatización es posible (R2.6) y si
    ///     corre en simulador (R5.2).
    ///   - onOnboardingFinished: handler que el contenedor inyecta para avanzar
    ///     el onboarding al confirmar (R6.3); devolver `false` señala que el
    ///     avance falló y deja la guía en el cierre para reintentar (R6.4). En
    ///     `Mode.standalone` puede omitirse: al confirmar, `isFinished` basta
    ///     para que la vista cierre la hoja (R1.4).
    public init(
        mode: Mode,
        content: GuiaApplePayContent? = .standard,
        environment: any ApplePayEnvironmentProbing,
        onOnboardingFinished: (() async -> Bool)? = nil) {
        self.mode = mode
        self.content = content
        self.onOnboardingFinished = onOnboardingFinished
        currentScreen = .requirements
        presentationError = nil
        summaryUnavailable = false
        advanceError = nil
        isFinished = false
        isAutomationAvailable = environment.isShortcutsAutomationAvailable
        isRunningInSimulator = environment.isRunningInSimulator
    }

    // MARK: - Navegación (máquina de estados)

    /// Presenta la primera pantalla de la guía. Con contenido válido, deja la
    /// máquina en `.requirements` — siempre la primera, antes de cualquier paso
    /// de configuración (R5.3); el llamador (onboarding) mide el ≤1s (R1.2).
    ///
    /// Si el contenido no se pudo cargar (`content == nil`), fija
    /// `presentationError` y **no** cambia de pantalla, para que el onboarding
    /// se mantenga en su paso actual y pueda ofrecer "Reintentar" (R1.5).
    public func presentFirstScreen() {
        guard content != nil else {
            presentationError = Self.presentationErrorMessage
            return
        }
        presentationError = nil
        currentScreen = .requirements
    }

    /// Avanza a la siguiente pantalla. Mueve el índice exactamente en 1 mientras
    /// haya una pantalla posterior; en la última pantalla (`.closing`) es un
    /// no-op — ahí el control activo es "confirmar", no "siguiente" (invariantes
    /// 1, 3 y 5 del diseño).
    public func next() {
        guard let following = Screen(rawValue: currentScreen.rawValue + 1) else {
            return
        }
        currentScreen = following
    }

    /// Retrocede a la pantalla anterior. Mueve el índice exactamente en 1
    /// mientras no sea la primera pantalla; en `.requirements` es un no-op —
    /// no se sale de la guía retrocediendo (invariantes 1, 4 y 5 del diseño).
    public func back() {
        guard let previous = Screen(rawValue: currentScreen.rawValue - 1) else {
            return
        }
        currentScreen = previous
    }

    /// Reintenta mostrar la primera pantalla tras un fallo de presentación
    /// (R1.5). Limpia el error previo y vuelve a intentar `presentFirstScreen()`.
    public func retryPresentation() {
        presentationError = nil
        presentFirstScreen()
    }

    // MARK: - Resumen de cierre (R6.1, R6.2)

    /// El resumen de la pantalla de cierre: un `CompletionStep` por cada paso de
    /// configuración (`content.shortcutSteps`), en el mismo orden y preservando
    /// el título de cada paso (R6.1, Property 6). Todos se marcan completados:
    /// llegar al cierre implica haber recorrido la guía entera.
    ///
    /// Si el contenido no está disponible (`content == nil`), el resumen queda
    /// vacío; el llamador detecta ese caso vía `summaryUnavailable` (R6.2) y aun
    /// así conserva el control de confirmar.
    public var completionSummary: [CompletionStep] {
        guard let content else { return [] }
        return content.shortcutSteps.map { step in
            CompletionStep(id: step.id, title: step.title, isCompleted: true)
        }
    }

    // MARK: - Finalización (R1.3, R6.2, R6.3, R6.4)

    /// Omite la guía (R1.3). Marca `isFinished` sin activar la captura de Apple
    /// Pay ni cerrar el onboarding: quien avanza el paso del onboarding sin
    /// cerrar el flujo es el contenedor (`OnboardingModel`) al observar que la
    /// guía terminó. No invoca el handler de finalización.
    public func skip() {
        advanceError = nil
        isFinished = true
    }

    /// Confirma la finalización desde la pantalla de cierre (R6.3 / R6.4).
    ///
    /// Antes de confirmar, si el contenido no está disponible marca el resumen
    /// como no disponible (R6.2) pero mantiene disponible el control de
    /// confirmar. En `Mode.onboarding` invoca `onOnboardingFinished`; si ese
    /// avance falla, fija `advanceError`, se mantiene en `.closing` y conserva
    /// el resumen para reintentar (R6.4). En `Mode.standalone` marca
    /// `isFinished` para que la vista cierre la hoja (R1.4).
    public func confirmCompletion() async {
        summaryUnavailable = (content == nil)
        advanceError = nil

        switch mode {
        case .onboarding:
            guard let onOnboardingFinished else {
                // Sin handler cableado no hay a dónde avanzar: se trata como
                // finalizado para no dejar al usuario atrapado en el cierre.
                isFinished = true
                return
            }
            let advanced = await onOnboardingFinished()
            if advanced {
                isFinished = true
            } else {
                // El avance falló: permanece en `.closing`, conserva el resumen
                // y expone el error para reintentar (R6.4).
                advanceError = Self.advanceErrorMessage
            }
        case .standalone:
            isFinished = true
        }
    }

    /// Reintenta avanzar el onboarding tras un fallo de confirmación (R6.4).
    /// Limpia el `advanceError` previo y vuelve a intentar `confirmCompletion()`,
    /// que conserva el resumen y el estado `.closing` si vuelve a fallar.
    public func retryAdvance() async {
        advanceError = nil
        await confirmCompletion()
    }

    /// Mensaje mostrado cuando no se puede cargar la guía (R1.5). Sale de
    /// `GuiaApplePayError.contentUnavailable` — única fuente del texto.
    private static let presentationErrorMessage =
        GuiaApplePayError.contentUnavailable.errorDescription

    /// Mensaje mostrado cuando el avance del onboarding falla tras confirmar
    /// (R6.4). Sale de `GuiaApplePayError.onboardingAdvanceFailed`.
    private static let advanceErrorMessage =
        GuiaApplePayError.onboardingAdvanceFailed.errorDescription
}

import LanaCore
import Testing
@testable import OnboardingFeature

/// Tests de ejemplo para la entrada, la omisión y el handler de finalización de
/// `GuiaApplePayModel` (Docs/CONVENTIONS.md: Swift Testing, no XCTest). Cubren
/// los criterios R1.2 (presentar la primera pantalla), R1.3 (omitir sin avanzar
/// ni capturar) y R6.3 (confirmar invoca el handler una vez).
@Suite("Guía Apple Pay — entrada, omitir y finalización")
@MainActor
struct GuiaApplePayModelEntryTests {
    // MARK: - Espía del handler de finalización (R6.3)

    /// Espía del handler `onOnboardingFinished`, aislado al `MainActor` como el
    /// propio modelo. Cuenta cuántas veces se invoca y devuelve un resultado
    /// configurable para simular avance exitoso o fallido.
    @MainActor
    final class FinishHandlerSpy {
        private(set) var callCount = 0
        private let result: Bool

        init(result: Bool = true) {
            self.result = result
        }

        /// El handler que se inyecta al modelo. Cada invocación incrementa el
        /// contador y devuelve el resultado configurado.
        func handler() -> Bool {
            callCount += 1
            return result
        }
    }

    // MARK: - R1.2: presentar la primera pantalla

    @Test("presentFirstScreen() con contenido válido deja la máquina en .requirements")
    func presentaRequisitosConContenidoValido() {
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment())

        modelo.presentFirstScreen()

        #expect(modelo.currentScreen == .requirements)
    }

    // MARK: - R1.3: omitir sin avanzar ni capturar

    @Test("skip() fija isFinished sin invocar el handler de avance")
    func omitirFinalizaSinAvanzar() {
        let espia = FinishHandlerSpy()
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment(),
            onOnboardingFinished: { espia.handler() })

        modelo.skip()

        #expect(modelo.isFinished)
        #expect(espia.callCount == 0)
    }

    // MARK: - R6.3: confirmar invoca el handler una vez

    @Test("confirmCompletion() en Mode.onboarding invoca onOnboardingFinished una vez")
    func confirmarInvocaHandlerUnaVez() async {
        let espia = FinishHandlerSpy(result: true)
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment(),
            onOnboardingFinished: { espia.handler() })

        await modelo.confirmCompletion()

        #expect(espia.callCount == 1)
    }
}

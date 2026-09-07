import LanaCore
import Testing
@testable import OnboardingFeature

/// Tests de ejemplo para el contenedor `OnboardingModel` (Docs/CONVENTIONS.md:
/// Swift Testing, no XCTest). Cubren la presencia del punto de entrada de la
/// guía (R1.1), la omisión que avanza el propio paso sin cerrar el flujo (R1.3)
/// y la finalización que invoca `onOnboardingFinished` en el último paso (R6.3).
@Suite("Onboarding — contenedor y pasos")
@MainActor
struct OnboardingModelTests {
    /// Espía del handler `onOnboardingFinished`, aislado al `MainActor`.
    @MainActor
    final class FinishHandlerSpy {
        private(set) var callCount = 0
        private let result: Bool

        init(result: Bool = true) {
            self.result = result
        }

        func handler() -> Bool {
            callCount += 1
            return result
        }
    }

    // MARK: - R1.1: punto de entrada de la guía presente y etiquetado

    @Test("El onboarding incluye el punto de entrada a la guía de Apple Pay")
    func incluyePuntoDeEntradaDeLaGuia() {
        let modelo = OnboardingModel(onOnboardingFinished: { true })

        #expect(modelo.steps.contains(.applePayGuide))
    }

    @Test("El punto de entrada está etiquetado exactamente «Configurar Apple Pay»")
    func puntoDeEntradaEtiquetado() {
        #expect(OnboardingModel.Step.applePayGuide.title == "Configurar Apple Pay")
    }

    @Test("El paso inicial es el punto de entrada de la guía")
    func pasoInicialEsLaGuia() {
        let modelo = OnboardingModel(onOnboardingFinished: { true })

        #expect(modelo.currentStep == .applePayGuide)
    }

    /// R1.1 exige que el punto de entrada sea, además de visible y etiquetado,
    /// *seleccionable*. En un onboarding recién construido y no terminado, el
    /// punto de entrada de la guía debe estar disponible como el paso actual
    /// accionable (no `nil`), de modo que la vista pueda presentarlo y el
    /// usuario seleccionarlo.
    @Test("El punto de entrada de la guía está disponible como paso actual seleccionable")
    func puntoDeEntradaEsSeleccionable() {
        let modelo = OnboardingModel(onOnboardingFinished: { true })

        #expect(modelo.isFinished == false)
        #expect(modelo.currentStep == .applePayGuide)
        #expect(modelo.steps.first == .applePayGuide)
    }

    // MARK: - R1.3: omitir avanza el paso sin invocar el avance final

    @Test("skipCurrentStep() en el último paso no invoca onOnboardingFinished y termina el flujo")
    func omitirUltimoPasoNoInvocaHandler() {
        let espia = FinishHandlerSpy()
        let modelo = OnboardingModel(
            steps: [.applePayGuide],
            onOnboardingFinished: { espia.handler() })

        modelo.skipCurrentStep()

        #expect(espia.callCount == 0)
        #expect(modelo.isFinished)
    }

    // MARK: - R6.3: confirmar el último paso invoca onOnboardingFinished

    @Test("finishCurrentStep() en el último paso invoca onOnboardingFinished una vez")
    func finalizarUltimoPasoInvocaHandler() async {
        let espia = FinishHandlerSpy(result: true)
        let modelo = OnboardingModel(
            steps: [.applePayGuide],
            onOnboardingFinished: { espia.handler() })

        let avanzo = await modelo.finishCurrentStep()

        #expect(avanzo)
        #expect(espia.callCount == 1)
        #expect(modelo.isFinished)
    }

    // MARK: - R6.4: fallo de avance no termina el flujo

    @Test("finishCurrentStep() con avance fallido devuelve false y no termina el flujo")
    func finalizarConAvanceFallido() async {
        let espia = FinishHandlerSpy(result: false)
        let modelo = OnboardingModel(
            steps: [.applePayGuide],
            onOnboardingFinished: { espia.handler() })

        let avanzo = await modelo.finishCurrentStep()

        #expect(avanzo == false)
        #expect(modelo.isFinished == false)
    }
}

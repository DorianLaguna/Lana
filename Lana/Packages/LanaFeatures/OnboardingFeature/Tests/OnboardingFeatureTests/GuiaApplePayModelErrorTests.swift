import LanaCore
import Testing
@testable import OnboardingFeature

/// Tests de ejemplo para los caminos de error de `GuiaApplePayModel`
/// (Docs/CONVENTIONS.md: Swift Testing, no XCTest). Cubren los edge cases de:
/// fallo de presentación con `content == nil` y su reintento (R1.5),
/// incompatibilidad de la automatización expuesta por el entorno (R2.6),
/// resumen de cierre no disponible con confirmar aún activo (R6.2) y fallo de
/// avance tras confirmar que conserva el cierre y el resumen (R6.4).
@Suite("Guía Apple Pay — caminos de error")
@MainActor
struct GuiaApplePayModelErrorTests {
    // MARK: - R1.5: fallo de presentación y reintento

    @Test("presentFirstScreen() con content == nil fija presentationError y no cambia de pantalla")
    func presentacionFallaConContenidoNil() {
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: nil,
            environment: InMemoryApplePayEnvironment())

        let pantallaAntes = modelo.currentScreen
        modelo.presentFirstScreen()

        #expect(modelo.presentationError != nil)
        #expect(modelo.currentScreen == pantallaAntes)
    }

    @Test("retryPresentation() con content == nil reintenta y vuelve a fijar el error")
    func reintentoPresentacionConContenidoNil() {
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: nil,
            environment: InMemoryApplePayEnvironment())

        modelo.presentFirstScreen()
        #expect(modelo.presentationError != nil)

        modelo.retryPresentation()

        // Sigue sin contenido: el reintento vuelve a fallar sin cambiar de
        // pantalla, dejando el error listo para otro intento.
        #expect(modelo.presentationError != nil)
        #expect(modelo.currentScreen == .requirements)
    }

    @Test("retryPresentation() con contenido válido limpia el error y presenta la primera pantalla")
    func reintentoPresentacionConContenidoValido() {
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment())

        modelo.retryPresentation()

        #expect(modelo.presentationError == nil)
        #expect(modelo.currentScreen == .requirements)
    }

    // MARK: - R2.6: incompatibilidad de la automatización

    @Test("Con isShortcutsAutomationAvailable == false el modelo expone la incompatibilidad")
    func incompatibilidadDeAutomatizacionExpuesta() {
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment(isShortcutsAutomationAvailable: false))

        #expect(modelo.isAutomationAvailable == false)
    }

    @Test("Con isShortcutsAutomationAvailable == true el modelo reporta compatibilidad")
    func compatibilidadDeAutomatizacionExpuesta() {
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment(isShortcutsAutomationAvailable: true))

        #expect(modelo.isAutomationAvailable == true)
    }

    // MARK: - R6.2: resumen de cierre no disponible con confirmar activo

    @Test("Con content == nil, confirmCompletion() fija summaryUnavailable y deja confirmar disponible")
    func resumenNoDisponibleAlConfirmarSinContenido() async {
        // Con `content == nil` el resumen no puede cargarse; confirmar debe
        // seguir disponible (aquí sin handler, el modelo trata el cierre como
        // finalizado en vez de dejar al usuario atrapado).
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: nil,
            environment: InMemoryApplePayEnvironment())

        #expect(modelo.completionSummary.isEmpty)

        await modelo.confirmCompletion()

        #expect(modelo.summaryUnavailable == true)
        // Confirmar quedó disponible y se pudo ejecutar: sin handler cableado
        // el modelo marca finalizado en lugar de quedar bloqueado.
        #expect(modelo.isFinished)
        #expect(modelo.advanceError == nil)
    }

    // MARK: - R6.4: fallo de avance conserva cierre y resumen

    @Test("Con avance fallido, confirmCompletion() fija advanceError, permanece en .closing y conserva el resumen")
    func avanceFallidoConservaCierreYResumen() async {
        // Handler que siempre falla el avance del onboarding (R6.4).
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment(),
            onOnboardingFinished: { false })

        // Recorre la guía hasta la pantalla de cierre.
        modelo.presentFirstScreen()
        while modelo.currentScreen != .closing {
            modelo.next()
        }
        #expect(modelo.currentScreen == .closing)

        let resumenAntes = modelo.completionSummary
        #expect(!resumenAntes.isEmpty)

        await modelo.confirmCompletion()

        // El avance falló: error fijo, sigue en el cierre y no finalizó.
        #expect(modelo.advanceError != nil)
        #expect(modelo.currentScreen == .closing)
        #expect(modelo.isFinished == false)
        // El resumen se conserva idéntico para permitir un nuevo intento.
        #expect(modelo.completionSummary == resumenAntes)
    }

    @Test("retryAdvance() tras un fallo vuelve a intentar y conserva el cierre si falla de nuevo")
    func reintentoDeAvanceConservaCierre() async {
        let modelo = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment(),
            onOnboardingFinished: { false })

        modelo.presentFirstScreen()
        while modelo.currentScreen != .closing {
            modelo.next()
        }

        await modelo.confirmCompletion()
        #expect(modelo.advanceError != nil)

        await modelo.retryAdvance()

        // Vuelve a fallar: mismo estado conservado.
        #expect(modelo.advanceError != nil)
        #expect(modelo.currentScreen == .closing)
        #expect(modelo.isFinished == false)
    }
}

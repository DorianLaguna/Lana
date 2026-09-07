import LanaCore
import Testing
@testable import OnboardingFeature

// Feature: apple-pay-setup-guide, Property 1: Invariantes de la máquina de
// estados de navegación.
//
// Validates: Requirements 1.2, 5.3, 6.1
//
// Para toda secuencia finita de acciones `next`/`back` aplicadas a
// `GuiaApplePayModel` partiendo de `presentFirstScreen()` (con contenido
// válido), el `currentScreen.rawValue` se mantiene siempre dentro de
// `[0, Screen.allCases.count)`; la pantalla inicial es siempre `.requirements`;
// cada `next`/`back` mueve el índice a lo más en 1 (o lo deja igual en los
// extremos); y `Screen.requirements.rawValue < Screen.shortcutSteps.rawValue`
// (los requisitos de dispositivo y la limitación de simulador se presentan
// antes que los pasos de configuración).
@Suite("GuiaApplePayModel — Property 1: invariantes de la máquina de estados")
@MainActor
struct GuiaApplePayModelStateMachineTests {
    /// Una acción de navegación de la máquina de estados.
    private enum NavAction {
        case next
        case back
    }

    /// Construye un modelo con contenido válido y entorno en memoria, listo
    /// para navegar (`presentFirstScreen()` deja la máquina en `.requirements`).
    private func makeModel() -> GuiaApplePayModel {
        let model = GuiaApplePayModel(
            mode: .onboarding,
            content: .standard,
            environment: InMemoryApplePayEnvironment())
        model.presentFirstScreen()
        return model
    }

    /// El espacio de entrada de esta propiedad son las secuencias finitas de
    /// acciones `next`/`back`. Se generan al menos 100 secuencias aleatorias
    /// (de longitud variable) y, tras aplicar cada acción, se comprueban todas
    /// las invariantes de la máquina de estados.
    @Test("índice en rango, inicio en .requirements, movimientos ±1; ≥100 secuencias")
    func invariantesDeNavegacion() {
        let screenCount = GuiaApplePayModel.Screen.allCases.count
        #expect(screenCount > 0)

        // Invariante estructural del orden: requisitos antes que pasos (R5.3).
        #expect(
            GuiaApplePayModel.Screen.requirements.rawValue
                < GuiaApplePayModel.Screen.shortcutSteps.rawValue)

        var rng = SystemRandomNumberGenerator()

        for _ in 0 ..< 100 {
            let model = makeModel()

            // La pantalla inicial es SIEMPRE `.requirements` (R5.3).
            #expect(model.currentScreen == .requirements)
            #expect(model.currentScreen.rawValue == 0)

            // Secuencia aleatoria de longitud variable (>= screenCount para
            // forzar rozar ambos extremos varias veces).
            let length = Int.random(in: screenCount ... (screenCount * 4), using: &rng)
            let actions: [NavAction] = (0 ..< length).map { _ in
                Bool.random(using: &rng) ? .next : .back
            }

            for action in actions {
                let before = model.currentScreen.rawValue

                switch action {
                case .next: model.next()
                case .back: model.back()
                }

                let after = model.currentScreen.rawValue

                // Índice siempre en rango [0, screenCount).
                #expect(after >= 0)
                #expect(after < screenCount)

                // Cada acción mueve el índice a lo más en 1 (o 0 en extremos).
                let delta = after - before
                #expect(abs(delta) <= 1)

                // El movimiento es coherente con la acción: `next` nunca
                // retrocede y `back` nunca avanza.
                switch action {
                case .next:
                    #expect(delta == 0 || delta == 1)
                    // En el extremo superior, `next` es un no-op.
                    if before == screenCount - 1 {
                        #expect(after == before)
                    } else {
                        #expect(after == before + 1)
                    }
                case .back:
                    #expect(delta == 0 || delta == -1)
                    // En el extremo inferior, `back` es un no-op.
                    if before == 0 {
                        #expect(after == before)
                    } else {
                        #expect(after == before - 1)
                    }
                }
            }
        }
    }
}

import Testing
@testable import LanaCore

// Feature: apple-pay-setup-guide, Property 2: Los pasos de Atajos están
// numerados de forma consecutiva y ordenada
//
// Validates: Requirements 2.1
//
// Para toda la secuencia `GuiaApplePayContent.standard.shortcutSteps`, los
// identificadores `GuiaStep.id` forman una secuencia estrictamente creciente,
// sin huecos ni duplicados, empezando en 1 (`ids == [1, 2, ..., n]`), y el
// conjunto cubre los pasos mínimos requeridos (abrir Atajos, crear
// automatización, seleccionar disparador Wallet, agregar la acción del App
// Intent, guardar).
@Suite("GuiaApplePayContent — Property 2: numeración de pasos de Atajos")
struct GuiaApplePayContentStepNumberingTests {
    /// El espacio de entrada de esta propiedad es la secuencia fija
    /// `standard.shortcutSteps`. Se itera al menos 100 veces reconstruyendo la
    /// vista de la secuencia (incluyendo una permutación aleatoria como
    /// entrada barajada) para confirmar que la invariante de numeración no
    /// depende del orden de recorrido y se mantiene en cada corrida.
    @Test("ids == [1..n] consecutivos, sin huecos ni duplicados; ≥100 iteraciones")
    func idsSonConsecutivosDesdeUno() {
        let steps = GuiaApplePayContent.standard.shortcutSteps

        #expect(!steps.isEmpty, "Debe haber al menos los pasos mínimos requeridos")

        var rng = SystemRandomNumberGenerator()
        for _ in 0 ..< 100 {
            // Barajar la fuente para probar que la invariante depende de los
            // ids declarados, no del orden en que se leen.
            let shuffled = steps.shuffled(using: &rng)

            // ids ordenados deben ser exactamente [1, 2, ..., n].
            let sortedIds = shuffled.map(\.id).sorted()
            let expected = Array(1 ... shuffled.count)
            #expect(sortedIds == expected)

            // Sin duplicados.
            #expect(Set(sortedIds).count == sortedIds.count)

            // En orden de declaración, los ids también son estrictamente
            // crecientes de 1 en 1 (consecutivos, sin huecos).
            for (offset, step) in steps.enumerated() {
                #expect(step.id == offset + 1)
            }
        }
    }

    /// Cobertura de los pasos mínimos requeridos por R2.1: abrir Atajos, crear
    /// automatización, seleccionar disparador Wallet, agregar la acción del
    /// App Intent y guardar.
    @Test("cubre los pasos mínimos requeridos (abrir, crear, Wallet, acción, guardar)")
    func cubreLosPasosMinimosRequeridos() {
        let steps = GuiaApplePayContent.standard.shortcutSteps

        // Al menos los cinco pasos mínimos de R2.1.
        #expect(steps.count >= 5)

        // Texto combinado (título + detalle) en minúsculas, por paso, para
        // buscar la presencia de cada concepto mínimo sin acoplarse a un id.
        let haystacks = steps.map { "\($0.title) \($0.detail)".lowercased() }

        func covers(_ needles: [String]) -> Bool {
            haystacks.contains { text in needles.contains { text.contains($0) } }
        }

        // (a) abrir la app Atajos
        #expect(covers(["abre la app atajos", "app atajos", "atajos"]))
        // (b) crear una automatización nueva
        #expect(covers(["automatización nueva", "crea una automatización", "automatización personal"]))
        // (c) seleccionar el disparador Wallet
        #expect(covers(["disparador wallet", "disparador «wallet»", "wallet"]))
        // (d) agregar la acción del App Intent
        #expect(covers(["agregar transacción de apple pay", "agrega la acción", "acción de lana"]))
        // (e) guardar la automatización
        #expect(covers(["guarda la automatización", "guardar"]))
    }
}

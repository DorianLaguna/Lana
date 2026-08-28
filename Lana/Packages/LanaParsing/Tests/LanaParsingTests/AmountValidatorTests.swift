import Foundation
import Testing
@testable import LanaParsing

@Suite("AmountValidator")
struct AmountValidatorTests {
    let validator = AmountValidator()

    // swiftlint:disable force_unwrapping
    @Test("Extrae montos simples y con separador de miles", arguments: [
        ("gasté 300.50 en súper", [Decimal(string: "300.50")!]),
        ("1,250.50 de la luz", [Decimal(string: "1250.50")!]),
        ("unos tacos 85 varos", [Decimal(85)]),
        // Regresión: un número de 4+ dígitos sin coma de miles se partía en
        // "100" + "0" porque el grupo de miles no exigía al menos una coma.
        ("Despensa 1000 pesos en el Walmart", [Decimal(1000)]),
        ("Videojuego 1800 pesos", [Decimal(1800)])
    ])
    // swiftlint:enable force_unwrapping
    func extraeMontos(input: String, expected: [Decimal]) {
        #expect(validator.amounts(in: input) == expected)
    }

    @Test("Extrae varios montos en orden")
    func extraeVariosMontosEnOrden() {
        let amounts = validator.amounts(in: "2 boletos, 380 pesos")
        #expect(amounts == [2, 380])
    }

    @Test("Si el monto del modelo aparece en el texto, gana el modelo")
    func modeloGanaSiCoincide() {
        let result = validator.validate(modelAmount: 380, in: "2 boletos, 380 pesos")
        #expect(result.amount == 380)
        #expect(result.source == .model)
        #expect(!result.needsReview)
    }

    @Test("Si el modelo se equivoca de cifra, gana el regex")
    func regexGanaSiElModeloSeEquivoca() {
        // Caso real del spike: el modelo dijo 45000 donde el texto decía 45.
        let result = validator.validate(modelAmount: 45000, in: "45 de estacionamiento")
        #expect(result.amount == 45)
        #expect(result.source == .regex)
        #expect(result.needsReview)
    }

    @Test("Sin números en el texto, no se puede validar y se deja pasar el modelo")
    func sinNumerosNoSeValida() {
        let result = validator.validate(modelAmount: 300, in: "mil quinientos del súper")
        #expect(result.amount == 300)
        #expect(result.source == .unvalidated)
        #expect(!result.needsReview)
    }
}

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

/// El monto de una captura automática que llega como número o como texto
/// (ADR-0033) — el atajo de Apple Pay entrega 0 en el campo numérico
/// cuando Shortcuts pierde el tipo de una cantidad con moneda.
@Suite("AmountValidator.resolveAmount")
struct AmountValidatorResolveTests {
    private let validator = AmountValidator()

    @Test("El campo numérico gana cuando trae un monto")
    func elNumericoGanaCuandoTraeMonto() {
        #expect(validator.resolveAmount(numeric: 149.99, text: nil) == Decimal(string: "149.99"))
    }

    @Test("Un numérico en cero cae al texto — el fallo reportado")
    func unNumericoEnCeroCaeAlTexto() {
        #expect(validator.resolveAmount(numeric: 0, text: "$149.99") == Decimal(string: "149.99"))
    }

    @Test("Lee el monto con símbolo de moneda y separador de miles", arguments: [
        "$1,250.50", "MX$1,250.50", "1,250.50", "1250.50"
    ])
    func leeMontoConMonedaYSeparador(text: String) {
        #expect(validator.resolveAmount(numeric: 0, text: text) == Decimal(string: "1250.50"))
    }

    @Test("El texto se ignora si el numérico ya trae monto")
    func elTextoSeIgnoraSiElNumericoTraeMonto() {
        #expect(validator.resolveAmount(numeric: 50, text: "$999.00") == 50)
    }

    @Test("Sin monto usable en ninguno: nil, para no guardar un gasto de $0")
    func sinMontoUsableDevuelveNil() {
        #expect(validator.resolveAmount(numeric: 0, text: nil) == nil)
        #expect(validator.resolveAmount(numeric: 0, text: "") == nil)
        #expect(validator.resolveAmount(numeric: 0, text: "sin números") == nil)
        #expect(validator.resolveAmount(numeric: 0, text: "$0.00") == nil)
    }

    @Test("El numérico no arrastra el error binario de Double")
    func elNumericoNoArrastraElErrorBinarioDeDouble() throws {
        // `Decimal(149.99 as Double)` da 149.98999999999998.
        let resolved = try #require(validator.resolveAmount(numeric: 149.99, text: nil))
        #expect("\(resolved)" == "149.99")
    }
}

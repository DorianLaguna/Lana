import Foundation
import Testing
@testable import LanaDesign

@Suite("Teclear un monto (ADR-0056)")
struct AmountFieldTests {
    @Test("Cero se muestra vacío, para que el cursor no quede antes de un 0")
    func ceroSeMuestraVacio() {
        #expect(amountText(0).isEmpty)
        #expect(amountText(350) == "350")
        #expect(amountText(Decimal(string: "12.5") ?? 0) == "12.5")
    }

    @Test("Solo pasan dígitos y un separador decimal")
    func soloDigitosYUnSeparador() {
        #expect(sanitizedAmountInput("350").text == "350")
        #expect(sanitizedAmountInput("1,250.50").text == "1250.50")
        #expect(sanitizedAmountInput("12.5.7").text == "12.57")
        #expect(sanitizedAmountInput("12,5").text == "12.5")
        #expect(sanitizedAmountInput("$ 89 pesos").text == "89")
        #expect(sanitizedAmountInput(".5").text == "5")
        #expect(sanitizedAmountInput("").text.isEmpty)
    }

    @Test("El monto sale de lo tecleado, incluso a medio escribir")
    func elMontoSaleDeLoTecleado() {
        #expect(sanitizedAmountInput("350").amount == 350)
        #expect(sanitizedAmountInput("12.").amount == 12)
        #expect(sanitizedAmountInput("12.").text == "12.")
        #expect(sanitizedAmountInput("1,250.50").amount == Decimal(string: "1250.50"))
        #expect(sanitizedAmountInput("abc").amount == 0)
    }
}

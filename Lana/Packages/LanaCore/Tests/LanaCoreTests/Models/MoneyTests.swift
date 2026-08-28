import Foundation
import Testing
@testable import LanaCore

@Suite("Money")
struct MoneyTests {
    @Test("Suma montos de la misma moneda")
    func sumaMismaMoneda() throws {
        let first = try Money(amount: #require(Decimal(string: "300.10")), currency: .mxn)
        let second = try Money(amount: #require(Decimal(string: "120.20")), currency: .mxn)
        let total = try first + second
        #expect(total.amount == Decimal(string: "420.30"))
        #expect(total.currency == .mxn)
    }

    @Test("Sumar monedas distintas truena")
    func sumaMonedasDistintasTruena() {
        #expect(throws: MoneyError.self) {
            _ = try Money(amount: 100, currency: .mxn) + Money(amount: 100, currency: .usd)
        }
    }

    @Test("Resta montos de la misma moneda")
    func restaMismaMoneda() throws {
        let result = try Money(amount: 500, currency: .mxn) - Money(amount: 120, currency: .mxn)
        #expect(result.amount == 380)
    }

    @Test("La aritmética nunca pasa por Double")
    func decimalExacto() throws {
        // 0.1 + 0.2 en Double da 0.30000000000000004. Construir el Decimal
        // desde texto (no desde un literal flotante, que sí pasa por Double
        // antes de convertirse) es lo que garantiza el resultado exacto.
        let first = try Money(amount: #require(Decimal(string: "0.1")), currency: .mxn)
        let second = try Money(amount: #require(Decimal(string: "0.2")), currency: .mxn)
        let total = try first + second
        #expect(total.amount == Decimal(string: "0.3"))
    }
}

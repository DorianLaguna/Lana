import Foundation
import Testing
@testable import CardsFeature

@Suite("Cuánto del límite se debe")
struct LimitUsageTextTests {
    @Test("Una deuda que no divide exacto da su porcentaje, no 0%")
    func divisionQueNoTermina() throws {
        let debt = try #require(Decimal(string: "10719.59"))
        #expect(limitUsageText(debt: debt, limit: 17000) == "63%")
        #expect(limitUsageText(debt: 1000, limit: 3000) == "33%")
    }

    @Test("Con deuda por debajo del 1% dice menos de 1%, y sin deuda 0%")
    func porDebajoDelUno() {
        #expect(limitUsageText(debt: 50, limit: 17000) == "menos de 1%")
        #expect(limitUsageText(debt: 89, limit: 17000) == "1%")
        #expect(limitUsageText(debt: 0, limit: 17000) == "0%")
    }

    @Test("Sin límite no hay texto")
    func sinLimite() {
        #expect(limitUsageText(debt: 500, limit: 0) == nil)
    }
}

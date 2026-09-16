import Foundation
import Testing
@testable import LanaCore

@Suite("Percentage")
struct PercentageTests {
    @Test("Redondea divisiones que no terminan en vez de devolver 0")
    func divisionesQueNoTerminan() throws {
        let debt = try #require(Decimal(string: "10719.59"))
        #expect(Percentage.rounded(debt, of: 17000) == 63)
        #expect(Percentage.rounded(2, of: 3) == 67)
        let rate = try #require(Decimal(string: "0.2941"))
        #expect(Percentage.rounded(rate, of: 1) == 29)
    }

    @Test("Negativos y total cero")
    func negativosYCero() {
        #expect(Percentage.rounded(-1, of: 3) == -33)
        #expect(Percentage.rounded(5, of: 0) == 0)
    }
}

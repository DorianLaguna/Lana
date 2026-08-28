import Foundation
import Testing
@testable import LanaCore

@Suite("SplitRule")
struct SplitRuleTests {
    @Test("Iguales entre 3 reparte el residuo en el último participante por ID")
    func igualesConResiduo() throws {
        let ids = [ParticipantID(), ParticipantID(), ParticipantID()].sorted()
        let portions = try SplitRule.equally(among: ids).portions(of: Money(amount: 100, currency: .mxn))

        let sum = portions.values.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(sum == 100)
        #expect(portions[ids[0]]?.amount == Decimal(string: "33.33"))
        #expect(portions[ids[1]]?.amount == Decimal(string: "33.33"))
        #expect(portions[ids[2]]?.amount == Decimal(string: "33.34"))
    }

    @Test("payerOnly no genera partes")
    func payerOnlySinPartes() throws {
        let portions = try SplitRule.payerOnly.portions(of: Money(amount: 100, currency: .mxn))
        #expect(portions.isEmpty)
    }

    @Test("Proporcional respeta los shares congelados y suma exacto")
    func proporcionalSumaExacto() throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let rule = try SplitRule.proportional(shares: [
            alice: #require(Decimal(string: "0.6")),
            bob: #require(Decimal(string: "0.4"))
        ])
        let portions = try rule.portions(of: Money(amount: #require(Decimal(string: "999.99")), currency: .mxn))

        let sum = portions.values.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(sum == Decimal(string: "999.99"))
    }

    @Test("Proporcional que no suma 1 truena")
    func proporcionalInvalidoTruena() throws {
        let alice = ParticipantID()
        let rule = try SplitRule.proportional(shares: [alice: #require(Decimal(string: "0.5"))])
        #expect(throws: SplitRuleError.self) {
            _ = try rule.portions(of: Money(amount: 100, currency: .mxn))
        }
    }

    @Test("Porcentaje suma exacto al total")
    func porcentajeSumaExacto() throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let carol = ParticipantID()
        let rule = SplitRule.percentage(shares: [alice: 33, bob: 33, carol: 34])
        let portions = try rule.portions(of: Money(amount: 100, currency: .mxn))

        let sum = portions.values.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(sum == 100)
    }

    @Test("Montos exactos que no suman el total truena")
    func montosExactosInvalidoTruena() {
        let alice = ParticipantID()
        let rule = SplitRule.exactAmounts(amounts: [alice: 50])
        #expect(throws: SplitRuleError.self) {
            _ = try rule.portions(of: Money(amount: 100, currency: .mxn))
        }
    }
}

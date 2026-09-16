import Foundation
import Testing
@testable import LanaCore

@Suite("SplitRule")
struct SplitRuleTests {
    @Test("Iguales entre 3 reparte el centavo que sobra sin descuadrar el total")
    func igualesConResiduo() throws {
        let ids = [ParticipantID(), ParticipantID(), ParticipantID()].sorted()
        let portions = try SplitRule.equally(among: ids).portions(of: Money(amount: 100, currency: .mxn))

        let amounts = portions.values.map(\.amount).sorted()
        #expect(amounts.reduce(0, +) == 100)
        #expect(amounts == [Decimal(string: "33.33"), Decimal(string: "33.33"), Decimal(string: "33.34")])
    }

    @Test("El centavo que sobra no se lo lleva siempre la misma persona")
    func elCentavoRota() throws {
        let ids = [ParticipantID(), ParticipantID(), ParticipantID()].sorted()
        var receivers: Set<ParticipantID> = []
        for text in ["100", "100.01", "100.02"] {
            let total = try #require(Decimal(string: text))
            let portions = try SplitRule.equally(among: ids).portions(of: Money(amount: total, currency: .mxn))
            let largest = try #require(portions.max { $0.value.amount < $1.value.amount })
            receivers.insert(largest.key)
        }
        #expect(receivers.count > 1)
    }

    @Test("excluding quita a alguien de partes iguales y deja las demás reglas")
    func excludingSoloPartesIguales() {
        let (ana, bob, eva) = (ParticipantID(), ParticipantID(), ParticipantID())
        #expect(SplitRule.equally(among: [ana, bob, eva]).excluding([eva]) == .equally(among: [ana, bob]))
        #expect(SplitRule.equally(among: [ana, bob]).excluding([eva]) == nil)
        #expect(SplitRule.equally(among: [eva]).excluding([eva]) == nil)
        #expect(SplitRule.exactAmounts(amounts: [ana: 1, eva: 1]).excluding([eva]) == nil)
    }

    @Test("Iguales entre 7 de $350 da $50 exactos a cada quien, sin centavos de más")
    func igualesEntreSieteSinResiduo() throws {
        let ids = (0 ..< 7).map { _ in ParticipantID() }
        let portions = try SplitRule.equally(among: ids).portions(of: Money(amount: 350, currency: .mxn))

        #expect(portions.count == 7)
        #expect(portions.values.allSatisfy { $0.amount == 50 })
    }

    @Test("Ninguna parte se aleja más de un centavo de la exacta, y todo suma el total")
    func ningunaParteSeAlejaMasDeUnCentavo() throws {
        let totals = ["100", "350", "0.05", "999.99", "1234.57", "7"]
        for count in 2 ... 9 {
            let ids = (0 ..< count).map { _ in ParticipantID() }
            for text in totals {
                let total = try #require(Decimal(string: text))
                let portions = try SplitRule.equally(among: ids).portions(of: Money(amount: total, currency: .mxn))
                let amounts = portions.values.map(\.amount)
                #expect(amounts.reduce(0, +) == total, "\(text) entre \(count)")
                let spread = (amounts.max() ?? 0) - (amounts.min() ?? 0)
                #expect(spread <= Decimal(string: "0.01") ?? 0, "\(text) entre \(count): \(amounts)")
            }
        }
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

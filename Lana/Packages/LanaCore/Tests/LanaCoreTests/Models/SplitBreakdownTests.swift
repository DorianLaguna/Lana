import Foundation
import Testing
@testable import LanaCore

@Suite("Expense.splitShares (ADR-0029)")
struct SplitBreakdownTests {
    let alice = ParticipantID()
    let bob = ParticipantID()
    let listID = SharedListID()

    func expense(amount: Decimal, payer: ParticipantID?, split: SplitRule?, shared: Bool = true) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: "cena",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            sharedListID: shared ? listID : nil,
            payer: payer,
            split: split)
    }

    @Test("Un gasto personal no tiene desglose")
    func gastoPersonalNoTieneDesglose() {
        #expect(expense(amount: 100, payer: nil, split: nil, shared: false).splitShares() == nil)
    }

    @Test("Partes iguales reparte el total y suma exactamente el monto")
    func partesIgualesRepartElTotal() throws {
        let shares = try #require(
            expense(amount: 100, payer: alice, split: .equally(among: [alice, bob])).splitShares())

        #expect(shares.count == 2)
        let total = shares.reduce(Decimal(0)) { $0 + $1.amount.amount }
        #expect(total == 100)
        #expect(try #require(shares.first { $0.participant == alice }).amount.amount == 50)
    }

    @Test("Quien pagó va primero y queda marcado")
    func quienPagoVaPrimeroYQuedaMarcado() throws {
        let shares = try #require(
            expense(amount: 100, payer: bob, split: .equally(among: [alice, bob])).splitShares())

        #expect(shares.first?.participant == bob)
        #expect(shares.first?.isPayer == true)
        #expect(shares.last?.isPayer == false)
    }

    @Test("payerOnly le da el total a quien pagó, sin inventar deudas")
    func payerOnlyLeDaElTotalAQuienPago() throws {
        let shares = try #require(expense(amount: 100, payer: alice, split: .payerOnly).splitShares())

        #expect(shares.count == 1)
        #expect(shares.first?.participant == alice)
        #expect(shares.first?.amount.amount == 100)
    }

    @Test("Proporcional reparte según las participaciones congeladas")
    func proporcionalRepartSegunLasParticipaciones() throws {
        let split = try SplitRule.proportional(shares: [
            alice: #require(Decimal(string: "0.75")),
            bob: #require(Decimal(string: "0.25"))
        ])
        let shares = try #require(expense(amount: 1000, payer: alice, split: split).splitShares())

        #expect(try #require(shares.first { $0.participant == alice }).amount.amount == 750)
        #expect(try #require(shares.first { $0.participant == bob }).amount.amount == 250)
    }

    @Test("Un split inválido no produce un desglose inventado")
    func splitInvalidoNoProduceDesgloseInventado() throws {
        // Participaciones que no suman 1 — `portions(of:)` lanza, y esto
        // regresa `nil` en vez de repartir cualquier cosa.
        let split = try SplitRule.proportional(shares: [
            alice: #require(Decimal(string: "0.5")),
            bob: #require(Decimal(string: "0.2"))
        ])
        #expect(expense(amount: 100, payer: alice, split: split).splitShares() == nil)
    }
}

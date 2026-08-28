import Foundation
import Testing
@testable import LanaCore

@Suite("Projection")
struct ProjectionTests {
    let today = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Solo cuenta compromisos con fecha hasta el límite dado (ADR-0008)")
    func soloCuentaCompromisosConFechaHastaElLimite() throws {
        let commitments = [
            Commitment(
                concept: "renta",
                amount: Money(amount: -5000, currency: .mxn),
                date: today.addingTimeInterval(86400)),
            Commitment(
                concept: "tarjeta",
                amount: Money(amount: -2000, currency: .mxn),
                date: today.addingTimeInterval(86400 * 20))
        ]
        let available = try Projection.available(
            currentBalance: Money(amount: 10000, currency: .mxn),
            commitments: commitments,
            through: today.addingTimeInterval(86400 * 10))
        #expect(available.amount == 5000)
    }

    @Test("Mezclar monedas en la proyección truena")
    func mezclarMonedasTruena() {
        let commitments = [
            Commitment(concept: "algo", amount: Money(amount: -100, currency: .usd), date: today)
        ]
        #expect(throws: ProjectionError.self) {
            _ = try Projection.available(
                currentBalance: Money(amount: 1000, currency: .mxn),
                commitments: commitments,
                through: today)
        }
    }

    @Test("Sin compromisos, el disponible es el saldo real tal cual")
    func sinCompromisosEsElSaldoReal() throws {
        let available = try Projection.available(
            currentBalance: Money(amount: #require(Decimal(string: "1234.56")), currency: .mxn),
            commitments: [],
            through: today)
        #expect(available.amount == Decimal(string: "1234.56"))
    }
}

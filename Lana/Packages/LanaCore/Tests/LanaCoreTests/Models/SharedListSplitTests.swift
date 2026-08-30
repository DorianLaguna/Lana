import Foundation
import Testing
@testable import LanaCore

@Suite("SharedList — split proporcional por ingresos (ADR-0028)")
struct SharedListSplitTests {
    func list(_ incomes: [Decimal?]) -> SharedList {
        let participants = incomes.enumerated().map { index, income in
            Participant(displayName: "P\(index)", monthlyIncome: income)
        }
        return SharedList(
            name: "Depa",
            participants: participants,
            defaultSplit: .equally(among: participants.map(\.id)))
    }

    @Test("Con ingresos capturados, el split proporcional sale de ellos")
    func conIngresosCapturadosSaleElProporcional() throws {
        let depa = list([20000, 10000])
        let split = try #require(depa.proportionalSplitFromIncomes)

        guard case let .proportional(shares) = split else {
            Issue.record("Debería ser .proportional")
            return
        }
        let sum = shares.values.reduce(Decimal(0), +)
        #expect(sum == 1)
        // 20000/30000 y 10000/30000 — el que gana el doble pone el doble.
        let richer = try #require(depa.participants.first { $0.monthlyIncome == 20000 })
        let poorer = try #require(depa.participants.first { $0.monthlyIncome == 10000 })
        #expect(try #require(shares[richer.id]) > #require(shares[poorer.id]))
    }

    @Test("Las fracciones suman 1 exacto incluso cuando la división no termina — portions() lo exige")
    func lasFraccionesSuman1ExactoAunqueNoTermine() throws {
        // 1/3 no termina en Decimal: sin el ajuste de residuo, las
        // participaciones sumarían 0.999999 y `portions(of:)` lanzaría
        // `sharesDontSumToOne`.
        let depa = list([10000, 10000, 10000])
        let split = try #require(depa.proportionalSplitFromIncomes)

        let portions = try split.portions(of: Money(amount: 900, currency: .mxn))
        let total = portions.values.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(total == 900)
    }

    @Test("Las partes reparten el monto completo, proporcional al ingreso")
    func lasPartesRepartenElMontoCompleto() throws {
        let depa = list([30000, 10000])
        let split = try #require(depa.proportionalSplitFromIncomes)
        let portions = try split.portions(of: Money(amount: 1000, currency: .mxn))

        let richer = try #require(depa.participants.first { $0.monthlyIncome == 30000 })
        let poorer = try #require(depa.participants.first { $0.monthlyIncome == 10000 })
        #expect(try #require(portions[richer.id]).amount == 750)
        #expect(try #require(portions[poorer.id]).amount == 250)
    }

    @Test("Si alguien no tiene ingreso capturado, no hay proporcional — no se adivina")
    func sinIngresoDeAlguienNoHayProporcional() {
        #expect(list([20000, nil]).proportionalSplitFromIncomes == nil)
    }

    @Test("Ingresos en 0 no producen un split imposible")
    func ingresosEnCeroNoProducenSplitImposible() {
        #expect(list([0, 0]).proportionalSplitFromIncomes == nil)
    }

    @Test("preferredSplit usa el proporcional si existe, si no el default guardado")
    func preferredSplitPrefiereElProporcional() {
        let conIngresos = list([20000, 10000])
        let sinIngresos = list([nil, nil])

        guard case .proportional = conIngresos.preferredSplit else {
            Issue.record("Con ingresos debería preferir proporcional")
            return
        }
        #expect(sinIngresos.preferredSplit == sinIngresos.defaultSplit)
    }
}

import Foundation
import Testing
@testable import LanaCore

@Suite("PeriodComparison")
struct PeriodComparisonTests {
    private func expense(amount: Decimal, currency: Currency = .mxn, category: String = "otro") -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: currency),
            concept: "algo",
            category: category,
            date: .now)
    }

    private func statistics(_ expenses: [Expense]) -> PeriodStatistics {
        PeriodStatistics(expenses: expenses)
    }

    @Test("El cambio del gasto trae la diferencia y el porcentaje")
    func elCambioDelGastoTraeDiferenciaYPorcentaje() throws {
        let comparison = PeriodComparison(
            current: statistics([expense(amount: 1200)]),
            previous: statistics([expense(amount: 1000)]))

        let delta = try #require(comparison.expenseDelta(in: .mxn))
        #expect(delta.absolute == 200)
        #expect(delta.relative == Decimal(string: "0.2"))
        #expect(delta.direction == .up)
    }

    @Test("Sin periodo anterior no hay porcentaje de cambio, pero sí diferencia")
    func sinPeriodoAnteriorNoHayPorcentaje() throws {
        let comparison = PeriodComparison(
            current: statistics([expense(amount: 500)]),
            previous: statistics([]))

        let delta = try #require(comparison.expenseDelta(in: .mxn))
        #expect(delta.absolute == 500)
        #expect(delta.relative == nil)
    }

    @Test("Gastar menos da una diferencia negativa y dirección hacia abajo")
    func gastarMenosDaDiferenciaNegativa() throws {
        let comparison = PeriodComparison(
            current: statistics([expense(amount: 400)]),
            previous: statistics([expense(amount: 1000)]))

        let delta = try #require(comparison.expenseDelta(in: .mxn))
        #expect(delta.absolute == -600)
        #expect(delta.direction == .down)
    }

    @Test("Una categoría que dejó de gastarse aparece en la comparación")
    func unaCategoriaQueDejoDeGastarseAparece() {
        let comparison = PeriodComparison(
            current: statistics([expense(amount: 100, category: "comida")]),
            previous: statistics([
                expense(amount: 100, category: "comida"),
                expense(amount: 800, category: "ocio")
            ]))

        let deltas = comparison.categoryDeltas(in: .mxn)
        #expect(deltas.first?.category == "ocio")
        #expect(deltas.first?.delta.absolute == -800)
    }

    @Test("Las categorías se ordenan por cuánto se movieron, sin importar el signo")
    func lasCategoriasSeOrdenanPorTamanoDelCambio() {
        let comparison = PeriodComparison(
            current: statistics([
                expense(amount: 100, category: "comida"),
                expense(amount: 50, category: "ocio")
            ]),
            previous: statistics([
                expense(amount: 90, category: "comida"),
                expense(amount: 950, category: "ocio")
            ]))

        let deltas = comparison.categoryDeltas(in: .mxn)
        #expect(deltas.map(\.category) == ["ocio", "comida"])
    }

    @Test("No mezcla monedas: cada una se compara contra sí misma")
    func noMezclaMonedas() throws {
        let comparison = PeriodComparison(
            current: statistics([expense(amount: 100, currency: .mxn), expense(amount: 10, currency: .usd)]),
            previous: statistics([expense(amount: 50, currency: .mxn), expense(amount: 40, currency: .usd)]))

        #expect(try #require(comparison.expenseDelta(in: .mxn)).absolute == 50)
        #expect(try #require(comparison.expenseDelta(in: .usd)).absolute == -30)
    }
}

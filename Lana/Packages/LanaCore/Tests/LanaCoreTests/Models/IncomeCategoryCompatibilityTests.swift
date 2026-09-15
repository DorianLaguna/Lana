import Foundation
import Testing
@testable import LanaCore

/// Los eventos son inmutables y ya están guardados como JSON en
/// `CDEvent.payload` (ADR-0005). Agregarle campos a `IncomeAdded` solo es
/// seguro si los ingresos que ya existen siguen decodificando — si no, la app
/// dejaría de poder leer el historial de quien ya la usaba, que es la peor
/// falla posible aquí.
@Suite("IncomeAdded — compatibilidad del payload (ADR-0040)")
struct IncomeCategoryCompatibilityTests {
    /// El JSON tal como se guardaba antes de que existieran las categorías de
    /// ingreso.
    ///
    /// Se genera codificando un `IncomeAdded` real y quitándole las llaves
    /// nuevas, en vez de escribirlo a mano: así prueba la forma que de verdad
    /// produce el encoder y no una que yo suponga, y no se vuelve obsoleto la
    /// próxima vez que el evento gane un campo.
    private func legacyPayload() throws -> Data {
        let income = IncomeAdded(
            amount: Money(amount: 18000, currency: .mxn),
            concept: "quincena",
            category: IncomeCategory.sueldo.rawValue,
            subcategory: "nómina",
            date: Date(timeIntervalSince1970: 780_000_000))
        let encoded = try JSONEncoder().encode(income)
        var json = try #require(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "category")
        json.removeValue(forKey: "subcategory")
        return try JSONSerialization.data(withJSONObject: json)
    }

    @Test("Un ingreso guardado antes del cambio sigue decodificando, sin categoría")
    func unIngresoViejoSigueDecodificando() throws {
        let data = try legacyPayload()

        let income = try JSONDecoder().decode(IncomeAdded.self, from: data)

        #expect(income.concept == "quincena")
        #expect(income.amount.amount == 18000)
        #expect(income.category == nil)
        #expect(income.subcategory == nil)
    }

    @Test("Un ingreso viejo se pliega a una transacción sin categoría, no a una rota")
    func unIngresoViejoSePliegaBien() throws {
        let data = try legacyPayload()
        let income = try JSONDecoder().decode(IncomeAdded.self, from: data)

        let expenses = ExpenseProjection.expenses(from: [.incomeAdded(income)])

        #expect(expenses.count == 1)
        #expect(expenses.first?.kind == .income)
        #expect(expenses.first?.category == nil)
    }

    @Test("Un ingreso nuevo conserva su categoría al ir y volver del JSON")
    func unIngresoNuevoConservaSuCategoria() throws {
        let income = IncomeAdded(
            amount: Money(amount: 18000, currency: .mxn),
            concept: "quincena",
            category: IncomeCategory.sueldo.rawValue,
            subcategory: "nómina",
            date: Date(timeIntervalSince1970: 780_000_000))

        let data = try JSONEncoder().encode(income)
        let decoded = try JSONDecoder().decode(IncomeAdded.self, from: data)

        #expect(decoded.category == "sueldo")
        #expect(decoded.subcategory == "nómina")
    }

    @Test("La categoría del ingreso llega hasta el read model")
    func laCategoriaLlegaHastaElReadModel() {
        let income = IncomeAdded(
            amount: Money(amount: 18000, currency: .mxn),
            concept: "quincena",
            category: IncomeCategory.sueldo.rawValue,
            date: Date())

        let expenses = ExpenseProjection.expenses(from: [.incomeAdded(income)])

        #expect(expenses.first?.category == "sueldo")
    }

    @Test("Corregir un ingreso le cambia la categoría — reusa el evento que ya existía")
    func corregirUnIngresoLeCambiaLaCategoria() {
        let income = IncomeAdded(
            amount: Money(amount: 18000, currency: .mxn),
            concept: "quincena",
            category: IncomeCategory.otro.rawValue,
            date: Date())
        let correction = ExpenseCorrected(
            correctsEventID: income.id,
            category: IncomeCategory.sueldo.rawValue)

        let expenses = ExpenseProjection.expenses(from: [.incomeAdded(income), .expenseCorrected(correction)])

        #expect(expenses.first?.category == "sueldo")
    }

    @Test("Dos categorías de ingreso nunca comparten tono en la misma gráfica")
    func dosCategoriasDeIngresoNuncaCompartenTono() {
        let indexes = IncomeCategory.allCases.map(\.rampIndex)

        #expect(Set(indexes).count == IncomeCategory.allCases.count)
        #expect(indexes.allSatisfy { (0 ..< 12).contains($0) })
    }

    @Test("Las dos categorías más frecuentes, comida y sueldo, no salen del mismo color")
    func comidaYSueldoNoSalenIguales() {
        #expect(SuggestedCategory.comida.rampIndex != IncomeCategory.sueldo.rampIndex)
    }
}

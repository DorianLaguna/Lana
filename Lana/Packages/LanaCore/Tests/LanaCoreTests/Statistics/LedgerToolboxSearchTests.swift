import Foundation
import Testing
@testable import LanaCore

@Suite("LedgerToolbox.buscarPorConcepto (ADR-0058)")
struct LedgerToolboxSearchTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func expense(
        _ amount: Decimal,
        concept: String,
        category: String = "transporte",
        subcategory: String? = nil,
        currency: Currency = .mxn,
        date: Date) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: currency),
            concept: concept,
            category: category,
            subcategory: subcategory,
            date: date)
    }

    private func toolbox(_ store: InMemoryExpenseStore) -> LedgerToolbox {
        LedgerToolbox(
            store: store,
            sharedListStore: InMemorySharedListStore(),
            cardStore: InMemoryCardStore(),
            cardPaymentStore: InMemoryCardPaymentStore(),
            calendar: calendar)
    }

    @Test("Dice cuándo fue la última vez, cuántas van y cuánto suman")
    func ultimaVezYTotales() async throws {
        let today = try date(2026, 9, 17)
        let store = try InMemoryExpenseStore(seed: [
            expense(800, concept: "Gasolina Shell", date: date(2026, 3, 4)),
            expense(900, concept: "gasolina", date: date(2026, 7, 20)),
            expense(950, concept: "Gasolina Pemex", date: date(2026, 9, 12)),
            expense(120, concept: "Café", category: "comida", date: date(2026, 9, 15))
        ])

        let answer = await toolbox(store).buscarPorConcepto(texto: "gasolina", asOf: today)

        #expect(answer.contains("12 sep 2026"))
        #expect(answer.contains("Gasolina Pemex"))
        #expect(answer.contains("$950.00"))
        #expect(answer.contains("3 gastos"))
        #expect(answer.contains("$2,650.00"))
        #expect(answer.contains("desde marzo 2026"))
        #expect(!answer.contains("Café"))
    }

    @Test("Encuentra por categoría y subcategoría, sin acentos ni mayúsculas")
    func encuentraPorCategoriaYSubcategoria() async throws {
        let today = try date(2026, 9, 17)
        let store = try InMemoryExpenseStore(seed: [
            expense(300, concept: "Súper", category: "despensa", date: date(2026, 9, 1)),
            expense(150, concept: "Pan", category: "despensa", subcategory: "panadería", date: date(2026, 9, 5))
        ])

        let porCategoria = await toolbox(store).buscarPorConcepto(texto: "Despensa", asOf: today)
        #expect(porCategoria.contains("2 gastos"))

        let porSubcategoria = await toolbox(store).buscarPorConcepto(texto: "panaderia", asOf: today)
        #expect(porSubcategoria.contains("Pan"))
        #expect(porSubcategoria.contains("1 gasto"))
    }

    @Test("Sin resultados lo dice, y no inventa nada")
    func sinResultados() async throws {
        let today = try date(2026, 9, 17)
        let store = try InMemoryExpenseStore(seed: [
            expense(300, concept: "Súper", category: "despensa", date: date(2026, 9, 1))
        ])

        let answer = await toolbox(store).buscarPorConcepto(texto: "gasolina", asOf: today)

        #expect(answer == "No encontré ningún gasto que hable de \"gasolina\".")
    }

    @Test("Una búsqueda de una sola letra pide más detalle en vez de traer todo")
    func busquedaDemasiadoCorta() async throws {
        let store = InMemoryExpenseStore()
        let answer = try await toolbox(store).buscarPorConcepto(texto: "a", asOf: date(2026, 9, 17))
        #expect(answer.contains("muy corto"))
    }

    @Test("Cada moneda va en su línea: nunca se suman entre sí")
    func cadaMonedaPorSuLado() async throws {
        let today = try date(2026, 9, 17)
        let store = try InMemoryExpenseStore(seed: [
            expense(500, concept: "Gasolina", date: date(2026, 8, 2)),
            expense(40, concept: "Gasolina", currency: .usd, date: date(2026, 9, 10))
        ])

        let answer = await toolbox(store).buscarPorConcepto(texto: "gasolina", asOf: today)

        #expect(answer.contains("$500.00"))
        #expect(answer.contains("1 gasto por $500.00"))
        #expect(answer.split(separator: "\n").count == 3)
    }

    @Test("El catálogo la nombra, para que la UI la pueda sugerir")
    func elCatalogoLaNombra() {
        #expect(LedgerToolbox.catalog.contains { $0.name == "buscarPorConcepto" })
    }
}

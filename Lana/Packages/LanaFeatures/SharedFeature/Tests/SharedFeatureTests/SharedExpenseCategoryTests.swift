import Foundation
import LanaCore
import Testing
@testable import SharedFeature

@Suite("SharedListDetailModel — categoría y subcategoría")
@MainActor
struct SharedExpenseCategoryTests {
    let alice = Participant(displayName: "Alice")
    let bob = Participant(displayName: "Bob")

    @Test("recordExpense guarda la categoría cuando se le da una")
    func recordExpenseGuardaLaCategoria() async throws {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let expenseStore = InMemoryExpenseStore()
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: expenseStore,
            parser: InMemoryExpenseParsing())

        let saved = await model.recordExpense(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            category: "hogar",
            date: .now,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id]))

        #expect(saved)
        let expenses = try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(expenses.first?.category == "hogar")
    }

    @Test("recordExpense guarda la subcategoría cuando se le da una")
    func recordExpenseGuardaLaSubcategoria() async throws {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let expenseStore = InMemoryExpenseStore()
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: expenseStore,
            parser: InMemoryExpenseParsing())

        let saved = await model.recordExpense(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            category: "hogar",
            subcategory: "renta depa",
            date: .now,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id]))

        #expect(saved)
        let expenses = try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(expenses.first?.subcategory == "renta depa")
    }

    @Test("suggestCategory regresa la sugerencia del parser cuando hay concepto")
    func suggestCategoryRegresaLaSugerenciaDelParser() async {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let parser = InMemoryExpenseParsing(results: [
            ParseResult(concept: "renta", category: "hogar", subcategory: "renta depa")
        ])
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: InMemoryExpenseStore(),
            parser: parser)

        let suggestion = await model.suggestCategory(for: "renta")

        #expect(suggestion?.category == "hogar")
        #expect(suggestion?.subcategory == "renta depa")
    }

    @Test("suggestCategory regresa nil con el concepto vacío, sin llamar al parser")
    func suggestCategoryRegresaNilConConceptoVacio() async {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: InMemoryExpenseStore(),
            parser: InMemoryExpenseParsing(results: [ParseResult(category: "hogar")]))

        let suggestion = await model.suggestCategory(for: "   ")

        #expect(suggestion == nil)
    }
}

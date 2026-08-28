import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("EditExpenseModel")
@MainActor
struct EditExpenseModelTests {
    @Test("Guardar corrige el gasto existente, no crea uno nuevo")
    func guardarCorrigeElGastoExistente() async throws {
        let store = InMemoryExpenseStore()
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            date: .now)
        try await store.save(original)

        let model = EditExpenseModel(
            expense: original,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        model.category = "comida"
        _ = await model.save()

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.count == 1)
        #expect(saved.first?.id == original.id)
        #expect(saved.first?.category == "comida")
    }

    @Test("Corregir la categoría la registra como aprendizaje")
    func corregirLaCategoriaLaRegistraComoAprendizaje() async {
        let vocabularyStore = InMemoryCorrectionVocabularyStore()
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            date: .now)

        let model = EditExpenseModel(expense: original, store: InMemoryExpenseStore(), vocabularyStore: vocabularyStore)
        model.category = "comida"
        _ = await model.save()

        let entries = await vocabularyStore.topEntries(limit: 10)
        #expect(entries.first?.term == "Dulces")
        #expect(entries.first?.category == "comida")
    }

    @Test("Borrar quita el gasto del store")
    func borrarQuitaElGastoDelStore() async throws {
        let store = InMemoryExpenseStore()
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            date: .now)
        try await store.save(original)

        let model = EditExpenseModel(
            expense: original,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        let deleted = await model.delete()

        #expect(deleted)
        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.isEmpty)
    }

    @Test("No cambiar la categoría no registra nada")
    func noCambiarLaCategoriaNoRegistraNada() async {
        let vocabularyStore = InMemoryCorrectionVocabularyStore()
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            date: .now)

        let model = EditExpenseModel(expense: original, store: InMemoryExpenseStore(), vocabularyStore: vocabularyStore)
        _ = await model.save()

        let entries = await vocabularyStore.topEntries(limit: 10)
        #expect(entries.isEmpty)
    }

    @Test("onAppear carga las subcategorías ya usadas, agrupadas por categoría")
    func onAppearCargaSubcategoriasPorCategoria() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense, amount: Money(amount: 50, currency: .mxn), concept: "chicles",
            category: "despensa", subcategory: "dulces", date: .now))
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            date: .now)
        let model = EditExpenseModel(
            expense: original,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore())

        await model.onAppear()

        #expect(model.allSubcategories["despensa"] == ["dulces"])
    }

    @Test("Carga la subcategoría del gasto original, y se puede editar")
    func cargaLaSubcategoriaDelGastoOriginalYSePuedeEditar() {
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            subcategory: "dulces",
            date: .now)
        let model = EditExpenseModel(
            expense: original,
            store: InMemoryExpenseStore(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())

        #expect(model.subcategory == "dulces")

        model.subcategory = "chocolates"

        #expect(model.subcategory == "chocolates")
    }
}

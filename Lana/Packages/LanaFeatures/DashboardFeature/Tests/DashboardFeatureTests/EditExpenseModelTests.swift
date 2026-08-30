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
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())
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

        let model = EditExpenseModel(
            expense: original,
            store: InMemoryExpenseStore(),
            vocabularyStore: vocabularyStore,
            sharedListStore: InMemorySharedListStore())
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
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())
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

        let model = EditExpenseModel(
            expense: original,
            store: InMemoryExpenseStore(),
            vocabularyStore: vocabularyStore,
            sharedListStore: InMemorySharedListStore())
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
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())

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
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())

        #expect(model.subcategory == "dulces")

        model.subcategory = "chocolates"

        #expect(model.subcategory == "chocolates")
    }
}

@Suite("EditExpenseModel — mover entre personal y compartido (ADR-0027)")
@MainActor
struct EditExpenseSharedTests {
    let alice = Participant(displayName: "Alice")
    let bob = Participant(displayName: "Bob")

    @Test("Elegir una lista mueve el gasto personal a esa lista, con split preferido y pagador prellenado")
    func elegirListaMueveElGastoPersonal() async throws {
        let depa = SharedList(
            name: "Depa",
            participants: [
                Participant(id: alice.id, displayName: "Alice", monthlyIncome: 30000),
                Participant(id: bob.id, displayName: "Bob", monthlyIncome: 10000)
            ],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let sharedListStore = InMemorySharedListStore(seed: [depa])
        try await sharedListStore.setViewerParticipantID(bob.id, for: depa.id)
        let store = InMemoryExpenseStore()
        let expense = Expense(
            kind: .expense,
            amount: Money(amount: 1000, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            date: Date(timeIntervalSince1970: 1_700_000_000))
        try await store.save(expense)

        let model = EditExpenseModel(
            expense: expense,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: sharedListStore)
        await model.onAppear()
        model.sharedListID = depa.id
        model.sharedListChanged()

        // El pagador se prellena con "yo" en esa lista, no con el primero.
        #expect(model.payer == bob.id)
        #expect(model.displayName(for: bob.id) == "Yo")
        #expect(await model.save())

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first
        #expect(saved?.sharedListID == depa.id)
        #expect(saved?.payer == bob.id)
        // Con ingresos capturados, el split preferido es proporcional.
        guard case .proportional = saved?.split else {
            Issue.record("Debería haber quedado proporcional, quedó \(String(describing: saved?.split))")
            return
        }
    }

    @Test("Elegir «Personal» saca el gasto de la lista sin borrarlo")
    func elegirPersonalSacaElGastoDeLaLista() async throws {
        let depa = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let store = InMemoryExpenseStore()
        let expense = Expense(
            kind: .expense,
            amount: Money(amount: 500, currency: .mxn),
            concept: "cena",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            sharedListID: depa.id,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id]))
        try await store.save(expense)

        let model = EditExpenseModel(
            expense: expense,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore(seed: [depa]))
        await model.onAppear()
        model.sharedListID = nil
        model.sharedListChanged()

        #expect(model.payer == nil)
        #expect(await model.save())

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first
        #expect(saved?.concept == "cena")
        #expect(saved?.sharedListID == nil)
        #expect(saved?.split == nil)
    }
}

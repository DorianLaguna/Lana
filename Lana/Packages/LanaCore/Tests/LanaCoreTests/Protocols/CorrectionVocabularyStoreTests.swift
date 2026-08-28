import Testing
@testable import LanaCore

@Suite("InMemoryCorrectionVocabularyStore")
struct CorrectionVocabularyStoreTests {
    @Test("Registrar un término lo hace aparecer en topEntries")
    func registrarTerminoAparece() async {
        let store = InMemoryCorrectionVocabularyStore()
        await store.record(term: "bocina", category: "ocio")

        let entries = await store.topEntries(limit: 10)
        #expect(entries.count == 1)
        #expect(entries.first?.term == "bocina")
        #expect(entries.first?.category == "ocio")
    }

    @Test("Corregir el mismo término suma useCount en vez de duplicar")
    func mismoTerminoSumaUseCount() async {
        let store = InMemoryCorrectionVocabularyStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "Bocina", category: "ocio")
        await store.record(term: " bocina ", category: "ocio")

        let entries = await store.topEntries(limit: 10)
        #expect(entries.count == 1)
        #expect(entries.first?.useCount == 3)
    }

    @Test("topEntries prioriza uso frecuente")
    func topEntriesPriorizaUsoFrecuente() async {
        let store = InMemoryCorrectionVocabularyStore()
        await store.record(term: "poco usado", category: "otro")
        for _ in 0 ..< 5 {
            await store.record(term: "muy usado", category: "ocio")
        }

        let entries = await store.topEntries(limit: 1)
        #expect(entries.first?.term == "muy usado")
    }

    @Test("limit acota cuántas entradas se devuelven")
    func limitAcotaEntradas() async {
        let store = InMemoryCorrectionVocabularyStore()
        await store.record(term: "a", category: "otro")
        await store.record(term: "b", category: "otro")
        await store.record(term: "c", category: "otro")

        let entries = await store.topEntries(limit: 2)
        #expect(entries.count == 2)
    }

    @Test("allEntries devuelve todo, sin límite")
    func allEntriesDevuelveTodo() async {
        let store = InMemoryCorrectionVocabularyStore()
        await store.record(term: "a", category: "otro")
        await store.record(term: "b", category: "otro")

        let entries = await store.allEntries()
        #expect(entries.count == 2)
    }

    @Test("delete olvida solo el término indicado")
    func deleteOlvidaUnTermino() async {
        let store = InMemoryCorrectionVocabularyStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "chicles", category: "despensa")

        await store.delete(term: "bocina")

        let entries = await store.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.term == "chicles")
    }

    @Test("deleteAll olvida todo el vocabulario")
    func deleteAllOlvidaTodo() async {
        let store = InMemoryCorrectionVocabularyStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "chicles", category: "despensa")

        await store.deleteAll()

        let entries = await store.allEntries()
        #expect(entries.isEmpty)
    }
}

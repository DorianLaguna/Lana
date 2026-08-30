import Foundation
import LanaCore
import Testing
@testable import LanaPersistence

/// `CoreDataExpenseStore`'s `CorrectionVocabularyStore` conformance
/// (ADR-0012, ADR-0014) — extiende el mismo tipo que
/// `CoreDataExpenseStoreTests` (mismo `@Suite(.serialized)`, definido ahí)
/// en vez de declarar un `@Suite` nuevo: `.serialized` solo serializa
/// dentro de una suite, no entre suites, y cada test de aquí crea su
/// propio `NSPersistentContainer` — la misma razón por la que esa suite
/// existe.
extension CoreDataExpenseStoreTests {
    @Test("Registrar un término hace round-trip completo")
    func vocabularioHaceRoundTrip() async throws {
        let store = try await makeStore()
        await store.record(term: "bocina", category: "ocio")

        let entries = await store.topEntries(limit: 10)
        #expect(entries.count == 1)
        #expect(entries.first?.term == "bocina")
        #expect(entries.first?.category == "ocio")
        #expect(entries.first?.useCount == 1)
    }

    @Test("Corregir el mismo término suma useCount en vez de duplicar")
    func vocabularioMismoTerminoSumaUseCount() async throws {
        let store = try await makeStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "Bocina", category: "ocio")
        await store.record(term: " bocina ", category: "ocio")

        let entries = await store.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.useCount == 3)
    }

    @Test("delete olvida solo el término indicado")
    func vocabularioDeleteOlvidaUnTermino() async throws {
        let store = try await makeStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "chicles", category: "despensa")

        await store.delete(term: "bocina")

        let entries = await store.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.term == "chicles")
    }

    @Test("deleteAll olvida todo el vocabulario")
    func vocabularioDeleteAllOlvidaTodo() async throws {
        let store = try await makeStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "chicles", category: "despensa")

        await store.deleteAll()

        let entries = await store.allEntries()
        #expect(entries.isEmpty)
    }
}

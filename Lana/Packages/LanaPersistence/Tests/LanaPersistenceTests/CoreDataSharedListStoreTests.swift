import Foundation
import LanaCore
import Testing
@testable import LanaPersistence

/// `CoreDataExpenseStore`'s `SharedListStore` conformance — mismo patrón
/// que `CoreDataCardPaymentStoreTests`: extiende la suite `.serialized`
/// definida en `CoreDataExpenseStoreTests`, cada test con su propio
/// `NSPersistentContainer` en memoria.
extension CoreDataExpenseStoreTests {
    @Test("Guardar una lista hace round-trip completo, con roster y split default")
    func guardarUnaListaHaceRoundTrip() async throws {
        let store = try await makeStore()
        let alice = Participant(displayName: "Alice")
        let bob = Participant(displayName: "Bob")
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))

        try await store.save(list)
        let lists = try await store.lists()

        #expect(lists.count == 1)
        #expect(lists.first?.name == "Depa")
        #expect(lists.first?.participants.map(\.displayName).sorted() == ["Alice", "Bob"])
        #expect(lists.first?.defaultSplit == .equally(among: [alice.id, bob.id]))
    }

    @Test("Guardar de nuevo la misma lista la reemplaza, no la duplica")
    func guardarDeNuevoLaMismaListaLaReemplaza() async throws {
        let store = try await makeStore()
        let alice = Participant(displayName: "Alice")
        var list = SharedList(id: SharedListID(), name: "Depa", participants: [alice], defaultSplit: .payerOnly)

        try await store.save(list)
        list.name = "Depa (renombrada)"
        try await store.save(list)

        let lists = try await store.lists()
        #expect(lists.count == 1)
        #expect(lists.first?.name == "Depa (renombrada)")
    }

    @Test("Borrar quita la lista del store")
    func borrarQuitaLaListaDelStore() async throws {
        let store = try await makeStore()
        let list = SharedList(
            name: "Viaje",
            participants: [Participant(displayName: "Alice")],
            defaultSplit: .payerOnly)
        try await store.save(list)

        try await store.delete(id: list.id)

        let lists = try await store.lists()
        #expect(lists.isEmpty)
    }

    @Test("Registrar una liquidación hace round-trip completo")
    func registrarUnaLiquidacionHaceRoundTrip() async throws {
        let store = try await makeStore()
        let alice = Participant(displayName: "Alice")
        let bob = Participant(displayName: "Bob")
        let list = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .payerOnly)
        try await store.save(list)
        let settlement = SettlementRecorded(
            sharedListID: list.id,
            from: bob.id,
            to: alice.id,
            amount: Money(amount: 500, currency: .mxn),
            paymentMethod: .transfer,
            date: .now)

        try await store.recordSettlement(settlement)
        let events = try await store.events()

        let recorded = events.compactMap { event -> SettlementRecorded? in
            guard case let .settlementRecorded(settlement) = event else { return nil }
            return settlement
        }
        #expect(recorded.count == 1)
        #expect(recorded.first?.from == bob.id)
        #expect(recorded.first?.to == alice.id)
        #expect(recorded.first?.amount.amount == 500)
    }

    @Test("Un gasto compartido guardado por ExpenseStore enlaza con su CDSharedList por relación, no solo por ID plano")
    func unGastoCompartidoEnlazaConSuListaPorRelacion() async throws {
        let store = try await makeStore()
        let alice = Participant(displayName: "Alice")
        let bob = Participant(displayName: "Bob")
        let list = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .payerOnly)
        try await store.save(list)

        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 400, currency: .mxn),
            concept: "renta",
            category: "hogar",
            date: .now,
            sharedListID: list.id,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id])))

        // No solo el `sharedListID` plano del payload — la relación real de
        // Core Data (`CDEvent.sharedList`) es lo que
        // `NSPersistentCloudKitContainer.share(_:to:)` necesita para mover
        // los eventos junto con la lista al compartir (Fase 8, G3).
        let linkedListName = try await store.linkedSharedListName(forEventKind: "expenseAdded")
        #expect(linkedListName == "Depa")
    }
}

private extension CoreDataExpenseStore {
    /// Solo para verificar en tests que `CDEvent.sharedList` quedó enlazado.
    func linkedSharedListName(forEventKind kind: String) async throws -> String? {
        try await context.perform { [context] in
            let request = CDEvent.fetchRequest()
            request.predicate = NSPredicate(format: "kind == %@", kind)
            request.fetchLimit = 1
            return try context.fetch(request).first?.sharedList?.name
        }
    }
}

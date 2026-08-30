import Foundation
import LanaCore
import Testing
@testable import LanaPersistence

/// `CoreDataExpenseStore`'s `CardStore` conformance (ADR-0014, mismo
/// container que `ExpenseStore`) — extiende el mismo tipo que
/// `CoreDataExpenseStoreTests` (mismo `@Suite(.serialized)`, definido ahí)
/// en vez de declarar un `@Suite` nuevo: `.serialized` solo serializa
/// dentro de una suite, no entre suites, y cada test de aquí crea su
/// propio `NSPersistentContainer` — la misma razón por la que esa suite
/// existe.
extension CoreDataExpenseStoreTests {
    @Test("Guardar y leer una tarjeta hace round-trip completo")
    func tarjetaHaceRoundTrip() async throws {
        let store = try await makeStore()
        let card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)

        try await store.save(card)
        let results = try await store.cards()

        #expect(results.count == 1)
        #expect(results.first?.id == card.id)
        #expect(results.first?.alias == "BBVA Oro")
        #expect(results.first?.limit == card.limit)
    }

    @Test("El tipo y el color de la tarjeta hacen round-trip")
    func tarjetaTipoYColorHacenRoundTrip() async throws {
        let store = try await makeStore()
        let card = try Card(
            alias: "Nu débito",
            lastFourDigits: "1234",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5,
            kind: .debit,
            colorHex: "#6C4FB3")

        try await store.save(card)
        let results = try await store.cards()

        #expect(results.first?.kind == .debit)
        #expect(results.first?.colorHex == "#6C4FB3")
    }

    @Test("Guardar de nuevo la misma tarjeta la reemplaza, no la duplica")
    func tarjetaGuardarDeNuevoReemplaza() async throws {
        let store = try await makeStore()
        var card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await store.save(card)

        card.alias = "BBVA Platino"
        try await store.save(card)

        let results = try await store.cards()
        #expect(results.count == 1)
        #expect(results.first?.alias == "BBVA Platino")
    }

    @Test("Borrar quita la tarjeta del store")
    func tarjetaBorrarLaQuita() async throws {
        let store = try await makeStore()
        let card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await store.save(card)
        try await store.delete(id: card.id)

        let results = try await store.cards()
        #expect(results.isEmpty)
    }
}

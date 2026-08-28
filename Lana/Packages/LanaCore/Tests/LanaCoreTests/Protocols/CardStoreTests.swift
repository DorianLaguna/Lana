import Foundation
import Testing
@testable import LanaCore

@Suite("InMemoryCardStore")
struct CardStoreTests {
    @Test("Guardar y leer tarjetas")
    func guardarYLeer() async throws {
        let store = InMemoryCardStore()
        let card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await store.save(card)

        let cards = try await store.cards()
        #expect(cards.map(\.id) == [card.id])
    }

    @Test("Guardar de nuevo la misma tarjeta la reemplaza, no la duplica")
    func guardarDeNuevoReemplaza() async throws {
        let store = InMemoryCardStore()
        var card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await store.save(card)

        card.alias = "BBVA Platino"
        try await store.save(card)

        let cards = try await store.cards()
        #expect(cards.count == 1)
        #expect(cards.first?.alias == "BBVA Platino")
    }

    @Test("Borrar quita la tarjeta del store")
    func borrarQuitaLaTarjeta() async throws {
        let store = InMemoryCardStore()
        let card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await store.save(card)
        try await store.delete(id: card.id)

        let cards = try await store.cards()
        #expect(cards.isEmpty)
    }
}

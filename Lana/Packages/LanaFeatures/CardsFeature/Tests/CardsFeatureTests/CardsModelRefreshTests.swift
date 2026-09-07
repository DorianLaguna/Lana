import Foundation
import LanaCore
import Testing
@testable import CardsFeature

/// El contrato del que depende `ContentView` para que un gasto recién
/// capturado aparezca sin salir y volver a entrar a la tarjeta (ADR-0032).
/// La instancia del detalle vive en `CardsModel`, no en la vista: si
/// `makeCardDetailModel` dejara de reutilizarla, o `refreshCurrentCardDetail`
/// operara sobre otra, el refresco volvería a no verse.
@Suite("CardsModel — refrescar el detalle en pantalla")
@MainActor
struct CardsModelRefreshTests {
    private func makeCard() throws -> Card {
        try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 28,
            dueDay: 5)
    }

    private func expense(_ concept: String, amount: Decimal, cardID: CardID) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: concept,
            category: "otro",
            date: Date(),
            paymentMethod: .credit(cardID: cardID))
    }

    @Test("Un gasto guardado mientras el detalle está abierto aparece al refrescarlo")
    func unGastoNuevoApareceAlRefrescarElDetalle() async throws {
        let card = try makeCard()
        let cardStore = InMemoryCardStore()
        try await cardStore.save(card)
        let store = InMemoryExpenseStore()
        let model = CardsModel(cardStore: cardStore, store: store, cardPaymentStore: InMemoryCardPaymentStore())
        await model.onAppear()

        // El usuario entra a la tarjeta.
        let detail = model.makeCardDetailModel(for: card)
        await detail.onAppear()
        #expect(detail.expenses.isEmpty)

        // Captura un gasto sin salir de la pantalla.
        try await store.save(expense("gasolina", amount: 500, cardID: card.id))
        await model.refreshCurrentCardDetail()

        #expect(detail.expenses.map(\.concept) == ["gasolina"])
    }

    @Test("makeCardDetailModel reutiliza la instancia de la tarjeta que ya se está viendo")
    func makeCardDetailModelReutilizaLaInstancia() async throws {
        let card = try makeCard()
        let cardStore = InMemoryCardStore()
        try await cardStore.save(card)
        let model = CardsModel(
            cardStore: cardStore,
            store: InMemoryExpenseStore(),
            cardPaymentStore: InMemoryCardPaymentStore())

        let first = model.makeCardDetailModel(for: card)
        let second = model.makeCardDetailModel(for: card)

        #expect(first === second)
    }
}

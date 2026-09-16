import Foundation
import LanaCore
import Testing
@testable import CardsFeature

@Suite("CardsModel — el total y el orden de la lista")
@MainActor
struct CardsModelTotalsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func card(_ alias: String) throws -> Card {
        try Card(
            alias: alias,
            lastFourDigits: "",
            limit: Money(amount: 20000, currency: .mxn),
            cutoffDay: 12,
            dueDay: 20)
    }

    /// Un cargo a la tarjeta es un gasto pagado con crédito — no hay un evento
    /// aparte de "cargo" (ADR-0014).
    private func charge(_ amount: Decimal, on card: Card) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "algo",
            category: "otro",
            date: date(2026, 9, 5),
            paymentMethod: .credit(cardID: card.id)))
    }

    private func makeModel(cards: [Card], events: [ExpenseEvent]) -> CardsModel {
        CardsModel(
            cardStore: InMemoryCardStore(seed: cards),
            store: InMemoryExpenseStore(),
            cardPaymentStore: InMemoryCardPaymentStore(seed: events),
            calendar: calendar,
            userDefaults: UserDefaults(suiteName: "cards-totals-tests") ?? .standard)
    }

    @Test("El total suma la deuda de todas las tarjetas de la misma moneda")
    func totalPorMoneda() async throws {
        let bancomer = try card("Bancomer")
        let nu = try card("Nu")
        let model = makeModel(
            cards: [bancomer, nu],
            events: [charge(1000, on: bancomer), charge(500, on: nu)])

        await model.onAppear()

        #expect(model.totalDebt.count == 1)
        #expect(model.totalDebt.first?.amount == 1500)
    }

    @Test("Dice en cuántas tarjetas hay deuda, no en cuántas hay")
    func cuantasDeben() async throws {
        let conDeuda = try card("Bancomer")
        let sinDeuda = try card("Nu")
        let model = makeModel(cards: [conDeuda, sinDeuda], events: [charge(1000, on: conDeuda)])

        await model.onAppear()

        #expect(model.cardsWithDebtCount == 1)
        #expect(model.cards.count == 2)
    }

    @Test("Las tarjetas se ordenan por deuda y las que no deben nada quedan al final")
    func ordenPorDeuda() async throws {
        let poca = try card("Poca")
        let mucha = try card("Mucha")
        let ninguna = try card("Ninguna")
        let model = makeModel(
            cards: [poca, ninguna, mucha],
            events: [charge(100, on: poca), charge(9000, on: mucha)])

        await model.onAppear()

        #expect(model.cardsByDebt.map(\.alias) == ["Mucha", "Poca", "Ninguna"])
    }
}

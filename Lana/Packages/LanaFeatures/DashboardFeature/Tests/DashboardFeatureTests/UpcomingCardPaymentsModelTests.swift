import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("UpcomingCardPaymentsModel")
@MainActor
struct UpcomingCardPaymentsModelTests {
    /// Cae en la primera quincena (día 1-15 del mes).
    private let firstHalf = Date(timeIntervalSince1970: 1_754_380_800)
    /// Cae en la segunda quincena (día 16 en adelante).
    private let secondHalf = Date(timeIntervalSince1970: 1_755_648_000)

    private func chargeEvent(amount: Decimal, cardID: CardID, date: Date) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            date: date,
            paymentMethod: .credit(cardID: cardID)))
    }

    private func makeCard(dueDay: Int) throws -> Card {
        try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 1,
            dueDay: dueDay,
            kind: .credit)
    }

    @Test("Una tarjeta con fecha límite dentro de la quincena vigente aparece, con lo que falta pagar")
    func tarjetaDentroDeLaQuincenaAparece() async throws {
        let card = try makeCard(dueDay: 10)
        let cardStore = InMemoryCardStore(seed: [card])
        // Cargo de un mes antes del corte (día 1), para que ya sea parte
        // del último estado de cuenta cerrado, no del ciclo abierto.
        let chargeDate = Calendar.current.date(byAdding: .month, value: -1, to: firstHalf) ?? firstHalf
        let cardPaymentStore = InMemoryCardPaymentStore(seed: [chargeEvent(
            amount: 1500,
            cardID: card.id,
            date: chargeDate)])
        let model = UpcomingCardPaymentsModel(cardStore: cardStore, cardPaymentStore: cardPaymentStore)

        await model.onAppear(asOf: firstHalf)

        #expect(model.dueThisPayPeriod.map(\.card.id) == [card.id])
        #expect(model.dueThisPayPeriod.first?.amount.amount == 1500)
        #expect(model.totalsByCurrency.first?.amount == 1500)
    }

    @Test("Una tarjeta con fecha límite fuera de la quincena vigente no aparece")
    func tarjetaFueraDeLaQuincenaNoAparece() async throws {
        let card = try makeCard(dueDay: 20)
        let cardStore = InMemoryCardStore(seed: [card])
        let chargeDate = Calendar.current.date(byAdding: .month, value: -1, to: firstHalf) ?? firstHalf
        let cardPaymentStore = InMemoryCardPaymentStore(seed: [chargeEvent(
            amount: 1500,
            cardID: card.id,
            date: chargeDate)])
        let model = UpcomingCardPaymentsModel(cardStore: cardStore, cardPaymentStore: cardPaymentStore)

        // Hoy (firstHalf) cae en la primera quincena — una tarjeta que
        // vence el 20 (segunda quincena) no debe aparecer todavía.
        await model.onAppear(asOf: firstHalf)

        #expect(model.dueThisPayPeriod.isEmpty)
    }

    @Test("Sin nada pendiente del último estado de cuenta, la tarjeta no aparece aunque venza esta quincena")
    func sinDeudaNoAparece() async throws {
        let card = try makeCard(dueDay: 10)
        let cardStore = InMemoryCardStore(seed: [card])
        let model = UpcomingCardPaymentsModel(cardStore: cardStore, cardPaymentStore: InMemoryCardPaymentStore())

        await model.onAppear(asOf: firstHalf)

        #expect(model.dueThisPayPeriod.isEmpty)
    }

    @Test("La segunda quincena solo agarra tarjetas con fecha límite del 16 en adelante")
    func segundaQuincenaAgarraDesdeEl16() async throws {
        let earlyCard = try makeCard(dueDay: 10)
        let lateCard = try Card(
            alias: "Nu",
            lastFourDigits: "1234",
            limit: Money(amount: 5000, currency: .mxn),
            cutoffDay: 1,
            dueDay: 20,
            kind: .credit)
        let cardStore = InMemoryCardStore(seed: [earlyCard, lateCard])
        let chargeDate = Calendar.current.date(byAdding: .month, value: -1, to: secondHalf) ?? secondHalf
        let cardPaymentStore = InMemoryCardPaymentStore(seed: [
            chargeEvent(amount: 800, cardID: earlyCard.id, date: chargeDate),
            chargeEvent(amount: 300, cardID: lateCard.id, date: chargeDate)
        ])
        let model = UpcomingCardPaymentsModel(cardStore: cardStore, cardPaymentStore: cardPaymentStore)

        await model.onAppear(asOf: secondHalf)

        #expect(model.dueThisPayPeriod.map(\.card.id) == [lateCard.id])
    }
}

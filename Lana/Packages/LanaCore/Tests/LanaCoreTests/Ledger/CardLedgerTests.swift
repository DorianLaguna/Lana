import Foundation
import Testing
@testable import LanaCore

@Suite("CardLedger")
struct CardLedgerTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func creditCard(cutoffDay: Int) throws -> Card {
        try Card(
            alias: "Nu",
            lastFourDigits: "1234",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: cutoffDay,
            dueDay: 15)
    }

    func charge(_ card: Card, amount: Decimal, on chargeDate: Date) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "compra",
            category: "otros",
            date: chargeDate,
            paymentMethod: .credit(cardID: card.id)))
    }

    @Test("Un cargo antes del corte cae en el ciclo anterior, no en el actual")
    func cargoAntesDelCorteCaeEnCicloAnterior() throws {
        let card = try creditCard(cutoffDay: 20)
        let events = [charge(card, amount: 500, on: date(2026, 8, 15))]
        let ledger = CardLedger(events: events)

        let asOf = date(2026, 8, 25)
        #expect(ledger.lastStatementBalance(for: card, asOf: asOf, calendar: calendar).amount == 500)
        #expect(ledger.currentCycleBalance(for: card, asOf: asOf, calendar: calendar).amount == 0)
    }

    @Test("Un cargo después del corte cae en el ciclo actual, no en el anterior")
    func cargoDespuesDelCorteCaeEnCicloActual() throws {
        let card = try creditCard(cutoffDay: 20)
        let events = [charge(card, amount: 500, on: date(2026, 8, 22))]
        let ledger = CardLedger(events: events)

        let asOf = date(2026, 8, 25)
        #expect(ledger.currentCycleBalance(for: card, asOf: asOf, calendar: calendar).amount == 500)
        #expect(ledger.lastStatementBalance(for: card, asOf: asOf, calendar: calendar).amount == 0)
    }

    @Test("Corte día 31 en febrero usa el último día del mes")
    func corte31EnFebreroUsaUltimoDia() throws {
        let card = try creditCard(cutoffDay: 31)
        let events = [charge(card, amount: 200, on: date(2026, 2, 27))]
        let ledger = CardLedger(events: events)

        // Corte de febrero 2026 cae el día 28 (último día del mes).
        let asOf = date(2026, 3, 1)
        #expect(ledger.lastStatementBalance(for: card, asOf: asOf, calendar: calendar).amount == 200)
    }

    @Test("El débito nunca genera deuda de tarjeta")
    func debitoNuncaGeneraDeuda() throws {
        let card = try creditCard(cutoffDay: 20)
        let debitCharge = ExpenseEvent.expenseAdded(ExpenseAdded(
            amount: Money(amount: 500, currency: .mxn),
            concept: "compra con débito",
            category: "otros",
            date: date(2026, 8, 15),
            paymentMethod: .debit(cardID: card.id)))
        let ledger = CardLedger(events: [debitCharge])

        let asOf = date(2026, 8, 25)
        #expect(ledger.lastStatementBalance(for: card, asOf: asOf, calendar: calendar).amount == 0)
        #expect(ledger.currentCycleBalance(for: card, asOf: asOf, calendar: calendar).amount == 0)
    }

    @Test("Anular un cargo lo saca del saldo de la tarjeta")
    func anularCargoLoExcluye() throws {
        let card = try creditCard(cutoffDay: 20)
        let event = charge(card, amount: 500, on: date(2026, 8, 22))
        let voided = ExpenseEvent.expenseVoided(ExpenseVoided(voidsEventID: event.id))
        let ledger = CardLedger(events: [event, voided])

        let asOf = date(2026, 8, 25)
        #expect(ledger.currentCycleBalance(for: card, asOf: asOf, calendar: calendar).amount == 0)
    }

    @Test("Un pago reduce lo pendiente del último estado de cuenta")
    func pagoReduceLoPendiente() throws {
        let card = try creditCard(cutoffDay: 20)
        let payment = ExpenseEvent.cardPaymentRecorded(CardPaymentRecorded(
            cardID: card.id,
            amount: Money(amount: 300, currency: .mxn),
            date: date(2026, 8, 22)))
        let ledger = CardLedger(events: [
            charge(card, amount: 500, on: date(2026, 8, 15)),
            payment
        ])

        let asOf = date(2026, 8, 25)
        #expect(ledger.lastStatementBalance(for: card, asOf: asOf, calendar: calendar).amount == 500)
        #expect(ledger.outstandingStatementBalance(for: card, asOf: asOf, calendar: calendar).amount == 200)
    }

    @Test("Un pago nunca cuenta como cargo nuevo")
    func pagoNuncaCuentaComoCargo() throws {
        let card = try creditCard(cutoffDay: 20)
        let payment = ExpenseEvent.cardPaymentRecorded(CardPaymentRecorded(
            cardID: card.id,
            amount: Money(amount: 300, currency: .mxn),
            date: date(2026, 8, 22)))
        let ledger = CardLedger(events: [payment])

        let asOf = date(2026, 8, 25)
        #expect(ledger.currentCycleBalance(for: card, asOf: asOf, calendar: calendar).amount == 0)
        #expect(ledger.lastStatementBalance(for: card, asOf: asOf, calendar: calendar).amount == 0)
    }
}

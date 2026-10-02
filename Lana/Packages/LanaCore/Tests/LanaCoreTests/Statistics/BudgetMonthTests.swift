import Foundation
import Testing
@testable import LanaCore

@Suite("A qué mes le cuenta un movimiento en Te queda")
struct BudgetMonthTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func card(cutoffDay: Int, kind: CardKind = .credit) throws -> Card {
        try Card(
            alias: "Bancomer",
            lastFourDigits: "1234",
            limit: Money(amount: 30000, currency: .mxn),
            cutoffDay: cutoffDay,
            dueDay: 12,
            kind: kind)
    }

    private func expense(_ amount: Decimal, on date: Date, paidWith method: PaymentMethod?) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: "compra",
            category: "otro",
            date: date,
            paymentMethod: method)
    }

    @Test("Con corte el 23, lo comprado el 24 le cuenta al mes siguiente")
    func despuesDelCorte() throws {
        let bancomer = try card(cutoffDay: 23)
        let purchase = expense(500, on: date(2026, 9, 24), paidWith: .credit(cardID: bancomer.id))

        #expect(BudgetMonth.month(of: purchase, cards: [bancomer], calendar: calendar) == date(2026, 10, 1, hour: 0))
    }

    @Test("Con corte el 23, lo comprado el 22 le cuenta a este mes")
    func antesDelCorte() throws {
        let bancomer = try card(cutoffDay: 23)
        let purchase = expense(500, on: date(2026, 9, 22), paidWith: .credit(cardID: bancomer.id))

        #expect(BudgetMonth.month(of: purchase, cards: [bancomer], calendar: calendar) == date(2026, 9, 1, hour: 0))
    }

    @Test("Débito, transferencia y una tarjeta ya borrada cuentan en el mes de su fecha")
    func sinCiclo() throws {
        let debit = try card(cutoffDay: 23, kind: .debit)
        let deleted = try card(cutoffDay: 23)
        let day = date(2026, 9, 28)
        let expenses = [
            expense(100, on: day, paidWith: .debit(cardID: debit.id)),
            expense(200, on: day, paidWith: .transfer),
            expense(300, on: day, paidWith: .credit(cardID: deleted.id))
        ]

        for item in expenses {
            #expect(BudgetMonth.month(of: item, cards: [debit], calendar: calendar) == date(2026, 9, 1, hour: 0))
        }
    }

    @Test("Octubre carga lo comprado con tarjeta tras el corte de septiembre, y no lo de después de su propio corte")
    func mesCompleto() throws {
        let bancomer = try card(cutoffDay: 23)
        let expenses = [
            expense(1000, on: date(2026, 9, 20), paidWith: .credit(cardID: bancomer.id)),
            expense(700, on: date(2026, 9, 26), paidWith: .credit(cardID: bancomer.id)),
            expense(2500, on: date(2026, 10, 2), paidWith: .transfer),
            expense(400, on: date(2026, 10, 25), paidWith: .credit(cardID: bancomer.id))
        ]

        let october = BudgetMonth.expenses(
            expenses,
            countingIn: date(2026, 10, 15),
            cards: [bancomer],
            calendar: calendar)

        #expect(october.map(\.amount.amount) == [700, 2500])
    }
}

import Foundation
import Testing
@testable import LanaCore

@Suite("Lo que ya tiene dueño en el mes")
struct MonthCommitmentsTests {
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

    private func recurring(
        _ name: String,
        _ amount: Decimal,
        day: Int,
        kind: Expense.Kind = .expense) throws -> RecurringItem {
        try RecurringItem(
            name: name,
            amount: Money(amount: amount, currency: .mxn),
            kind: kind,
            dayOfMonth: day)
    }

    private func resolve(
        items: [RecurringItem] = [],
        expenses: [Expense] = [],
        cards: [Card] = [],
        events: [ExpenseEvent] = [],
        asOf: Date) -> MonthCommitments {
        MonthCommitments.resolve(
            month: asOf,
            currency: .mxn,
            from: MonthCommitments.Inputs(
                recurringItems: items,
                expenses: expenses,
                cards: cards,
                ledger: CardLedger(events: events)),
            asOf: asOf,
            calendar: calendar)
    }

    @Test("Un recurrente que todavía no cae en el mes ya tiene dueño")
    func recurrentePendienteCuenta() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 30)], asOf: date(2026, 9, 15))

        #expect(result.recurring.map(\.concept) == ["Renta"])
        #expect(result.committed == 9000)
    }

    @Test("Lo que ya pasó este mes no se vuelve a contar")
    func loYaPasadoNoCuenta() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 1)], asOf: date(2026, 9, 15))

        #expect(result.recurring.isEmpty)
        #expect(result.committed == 0)
    }

    @Test("Un ingreso por venir no suma: Te queda cuenta lo registrado, no lo prometido")
    func elIngresoFuturoNoSuma() throws {
        let result = try resolve(
            items: [recurring("Sueldo", 12000, day: 30, kind: .income)],
            asOf: date(2026, 9, 15))

        #expect(result.recurring.isEmpty)
        #expect(result.committed == 0)
    }

    @Test("Lo libre es lo que queda del mes menos lo comprometido")
    func loLibre() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 30)], asOf: date(2026, 9, 15))

        #expect(result.free(after: 12000) == 3000)
    }

    @Test("Si lo que queda no alcanza para lo que viene, lo libre es negativo")
    func loLibreNegativo() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 30)], asOf: date(2026, 9, 15))

        #expect(result.free(after: 5000) == -4000)
    }

    @Test("Lo que cae justo después del mes se ve, pero no se suma")
    func justoDespuesNoSuma() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 2)], asOf: date(2026, 9, 28))

        #expect(result.recurring.isEmpty)
        #expect(result.justAfter.map(\.concept) == ["Renta"])
        #expect(result.committed == 0)
    }

    @Test("Un recurrente ya registrado en el mes deja de tener dueño: ya es un gasto real")
    func yaRegistradoNoCuenta() throws {
        let item = try recurring("Renta", 9000, day: 30)
        let registered = Expense(
            kind: .expense,
            amount: Money(amount: 9000, currency: .mxn),
            concept: "Renta",
            category: "hogar",
            date: date(2026, 9, 20),
            recurringItemID: item.id)

        let result = resolve(items: [item], expenses: [registered], asOf: date(2026, 9, 15))

        #expect(result.recurring.isEmpty)
        #expect(result.committed == 0)
    }

    @Test("Sin nada configurado no hay nada comprometido")
    func vacio() {
        let result = resolve(asOf: date(2026, 9, 15))

        #expect(result.isEmpty)
        #expect(result.committed == 0)
        #expect(result.free(after: 12000) == 12000)
    }

    // MARK: - Después del corte

    private func creditCard(alias: String = "Nu") throws -> Card {
        try Card(
            alias: alias,
            lastFourDigits: "1234",
            limit: Money(amount: 30000, currency: .mxn),
            cutoffDay: 10,
            dueDay: 20,
            kind: .credit)
    }

    private func cardCharge(_ amount: Decimal, on date: Date, card: Card) -> ExpenseEvent {
        ExpenseEvent.expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "compra",
            category: "otro",
            date: date,
            paymentMethod: .credit(cardID: card.id)))
    }

    @Test("Lo gastado después del corte se ve, pero no se suma a lo comprometido")
    func despuesDelCorteNoSeSuma() throws {
        let card = try creditCard()
        // El corte es el día 10: un cargo del 12 cae en el ciclo abierto.
        let result = resolve(
            cards: [card],
            events: [cardCharge(1450, on: date(2026, 9, 12), card: card)],
            asOf: date(2026, 9, 15))

        #expect(result.accruing.map(\.card) == ["Nu"])
        #expect(result.accruing.first?.amount == Money(amount: 1450, currency: .mxn))
        // No entra en la suma: esa factura todavía no cierra.
        #expect(result.committed == 0)
        #expect(result.free(after: 12000) == 12000)
    }

    @Test("Una tarjeta sin nada acumulado no aparece")
    func sinAcumuladoNoAparece() throws {
        let result = try resolve(cards: [creditCard()], asOf: date(2026, 9, 15))

        #expect(result.accruing.isEmpty)
    }

    @Test("Una tarjeta de débito no acumula: no tiene ciclo de corte")
    func elDebitoNoAcumula() throws {
        let debit = try Card(
            alias: "Nómina",
            lastFourDigits: "9999",
            limit: nil,
            cutoffDay: nil,
            dueDay: nil,
            kind: .debit)

        let result = resolve(
            cards: [debit],
            events: [cardCharge(500, on: date(2026, 9, 12), card: debit)],
            asOf: date(2026, 9, 15))

        #expect(result.accruing.isEmpty)
    }
}

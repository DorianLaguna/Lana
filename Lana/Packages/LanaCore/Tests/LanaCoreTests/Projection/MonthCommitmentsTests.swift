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
        asOf: Date) -> MonthCommitments {
        MonthCommitments.resolve(
            month: asOf,
            currency: .mxn,
            from: MonthCommitments.Inputs(recurringItems: items, expenses: expenses, cards: cards),
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
}

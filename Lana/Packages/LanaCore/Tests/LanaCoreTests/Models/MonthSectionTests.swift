import Foundation
import Testing
@testable import LanaCore

@Suite("Array<Expense>.groupedByMonth")
struct MonthSectionTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func expense(amount: Decimal, date: Date) -> Expense {
        Expense(kind: .expense, amount: Money(amount: amount, currency: .mxn), concept: "algo", date: date)
    }

    @Test("Agrupa por mes y ordena del más reciente al más antiguo")
    func agrupaPorMesYOrdena() throws {
        let expenses = try [
            expense(amount: 10, date: date(2026, 1, 5)),
            expense(amount: 20, date: date(2026, 3, 1)),
            expense(amount: 30, date: date(2026, 1, 20))
        ]

        let sections = expenses.groupedByMonth(calendar: calendar)

        #expect(sections.count == 2)
        #expect(try sections.first?.month == date(2026, 3, 1))
        #expect(sections.last?.items.count == 2)
    }

    @Test("Dentro del mes, lo más reciente va primero")
    func dentroDelMesLoMasRecienteVaPrimero() throws {
        let expenses = try [
            expense(amount: 10, date: date(2026, 1, 5)),
            expense(amount: 30, date: date(2026, 1, 20))
        ]

        let section = try #require(expenses.groupedByMonth(calendar: calendar).first)

        #expect(section.items.first?.amount.amount == 30)
    }

    @Test("Los meses sin movimiento simplemente no aparecen")
    func losMesesSinMovimientoNoAparecen() throws {
        let expenses = try [expense(amount: 10, date: date(2026, 1, 5))]

        #expect(expenses.groupedByMonth(calendar: calendar).count == 1)
    }
}

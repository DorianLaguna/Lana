import Foundation
import Testing
@testable import LanaCore

@Suite("Array<Expense>.groupedByDay")
struct DaySectionTests {
    @Test("Agrupa por día y ordena del más reciente al más antiguo")
    func agrupaYOrdena() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))

        let expenses = [
            Expense(kind: .expense, amount: Money(amount: 10, currency: .mxn), concept: "a", date: today),
            Expense(kind: .expense, amount: Money(amount: 20, currency: .mxn), concept: "b", date: yesterday),
            Expense(kind: .expense, amount: Money(amount: 30, currency: .mxn), concept: "c", date: today)
        ]

        let sections = expenses.groupedByDay(calendar: calendar)

        #expect(sections.count == 2)
        #expect(sections.first?.day == today)
        #expect(sections.first?.items.count == 2)
        #expect(sections.last?.day == yesterday)
    }
}

import Foundation
import Testing
@testable import LanaCore

@Suite("InMemoryExpenseStore")
struct InMemoryExpenseStoreTests {
    @Test("Guardar y leer por rango de fechas")
    func guardarYLeerPorRango() async throws {
        let store = InMemoryExpenseStore()
        let inRange = Expense(
            kind: .expense,
            amount: Money(amount: 100, currency: .mxn),
            concept: "café",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000))
        let outOfRange = Expense(
            kind: .expense,
            amount: Money(amount: 50, currency: .mxn),
            concept: "otro",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_800_000_000))
        try await store.save(inRange)
        try await store.save(outOfRange)

        let range = DateInterval(
            start: Date(timeIntervalSince1970: 1_699_000_000),
            end: Date(timeIntervalSince1970: 1_701_000_000))
        let results = try await store.expenses(in: range)

        #expect(results.map(\.id) == [inRange.id])
    }

    @Test("Borrar quita el gasto del store")
    func borrarQuitaElGasto() async throws {
        let store = InMemoryExpenseStore()
        let expense = Expense(
            kind: .expense,
            amount: Money(amount: 100, currency: .mxn),
            concept: "café",
            category: "comida",
            date: Date())
        try await store.save(expense)
        try await store.delete(id: expense.id)

        let range = DateInterval(start: Date.distantPast, end: Date.distantFuture)
        let results = try await store.expenses(in: range)
        #expect(results.isEmpty)
    }
}

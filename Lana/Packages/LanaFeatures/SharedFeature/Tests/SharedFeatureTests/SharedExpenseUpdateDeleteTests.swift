import Foundation
import LanaCore
import Testing
@testable import SharedFeature

@Suite("SharedListDetailModel — updateExpense/deleteExpense")
@MainActor
struct SharedExpenseUpdateDeleteTests {
    let alice = Participant(displayName: "Alice")
    let bob = Participant(displayName: "Bob")

    private func makeModel(expenseStore: any ExpenseStore) -> (SharedListDetailModel, SharedList) {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: expenseStore,
            parser: InMemoryExpenseParsing())
        return (model, list)
    }

    @Test("updateExpense conserva el id — corrige, no duplica")
    func updateExpenseConservaElID() async throws {
        let expenseStore = InMemoryExpenseStore()
        let (model, _) = makeModel(expenseStore: expenseStore)

        _ = await model.recordExpense(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            date: .now,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id]))
        let original = try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
            .first
        let originalID = try #require(original?.id)

        let updated = await model.updateExpense(
            id: originalID,
            amount: Money(amount: 150, currency: .mxn),
            concept: "renta actualizada",
            date: .now,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id]))

        #expect(updated)
        let expenses = try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(expenses.count == 1)
        #expect(expenses.first?.id == originalID)
        #expect(expenses.first?.concept == "renta actualizada")
        #expect(expenses.first?.amount == Money(amount: 150, currency: .mxn))
    }

    @Test("updateExpense sí cambia quién pagó y cómo se divide")
    func updateExpenseCambiaPagadorYSplit() async throws {
        let expenseStore = InMemoryExpenseStore()
        let (model, _) = makeModel(expenseStore: expenseStore)

        _ = await model.recordExpense(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            date: .now,
            payer: alice.id,
            split: .payerOnly)
        let originalID = try #require(
            try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first?.id)

        _ = await model.updateExpense(
            id: originalID,
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            date: .now,
            payer: bob.id,
            split: .equally(among: [alice.id, bob.id]))

        let expenses = try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(expenses.first?.payer == bob.id)
        #expect(expenses.first?.split == .equally(among: [alice.id, bob.id]))
    }

    @Test("deleteExpense lo quita del store")
    func deleteExpenseLoQuitaDelStore() async throws {
        let expenseStore = InMemoryExpenseStore()
        let (model, _) = makeModel(expenseStore: expenseStore)

        _ = await model.recordExpense(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            date: .now,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id]))
        let originalID = try #require(
            try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first?.id)

        let deleted = await model.deleteExpense(id: originalID)

        #expect(deleted)
        let expenses = try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(expenses.isEmpty)
    }
}

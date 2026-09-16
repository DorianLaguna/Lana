import Foundation
import LanaCore
import Testing
@testable import SharedFeature

@Suite("Sumar a alguien nuevo a lo ya registrado (ADR-0050)")
@MainActor
struct IncludeNewcomerTests {
    let alice = Participant(displayName: "Alice")
    let bob = Participant(displayName: "Bob")
    let carol = Participant(displayName: "Carol")

    private var everything: DateInterval {
        DateInterval(start: .distantPast, end: .distantFuture)
    }

    @Test("Los gastos de partes iguales se dividen entre uno más; los demás no se tocan")
    func soloPartesIguales() async throws {
        let expenseStore = InMemoryExpenseStore()
        let list = SharedList(
            name: "Viaje",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: expenseStore,
            parser: InMemoryExpenseParsing())
        await model.onAppear()

        _ = await model.recordExpense(
            amount: Money(amount: 300, currency: .mxn),
            concept: "gasolina",
            date: .now,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id]))
        _ = await model.recordExpense(
            amount: Money(amount: 100, currency: .mxn),
            concept: "casetas",
            date: .now,
            payer: alice.id,
            split: .exactAmounts(amounts: [alice.id: 70, bob.id: 30]))

        let withCarol = SharedList(
            id: list.id,
            name: list.name,
            participants: [alice, bob, carol],
            defaultSplit: .equally(among: [alice.id, bob.id, carol.id]))
        #expect(await model.updateList(withCarol))
        #expect(model.expensesToInclude([carol.id]).map(\.concept) == ["gasolina"])

        #expect(await model.include([carol.id]))

        let expenses = try await expenseStore.expenses(in: everything)
        let gasolina = try #require(expenses.first { $0.concept == "gasolina" })
        #expect(gasolina.splitShares()?.map(\.amount.amount) == [100, 100, 100])
        let casetas = try #require(expenses.first { $0.concept == "casetas" })
        #expect(casetas.split == .exactAmounts(amounts: [alice.id: 70, bob.id: 30]))
        #expect(model.expensesToInclude([carol.id]).isEmpty)
    }

    @Test("including no duplica a quien ya estaba y no aplica a otras reglas")
    func includingSoloAgregaFaltantes() {
        #expect(SplitRule.equally(among: [alice.id, bob.id]).including([bob.id]) == nil)
        #expect(SplitRule.equally(among: [alice.id]).including([bob.id, carol.id])
            == .equally(among: [alice.id, bob.id, carol.id]))
        #expect(SplitRule.payerOnly.including([carol.id]) == nil)
    }
}

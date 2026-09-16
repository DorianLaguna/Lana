import Foundation
import LanaCore
import Testing
@testable import SharedFeature

@Suite("De dónde sale una deuda (ADR-0053)")
@MainActor
struct DebtExplanationTests {
    @Test("La explicación usa los saldos de la lista y cuadra con la fila")
    func explicacionCuadra() async throws {
        let (yo, iori, liz, kin) = (
            Participant(displayName: "Yo"),
            Participant(displayName: "Iori"),
            Participant(displayName: "Liz"),
            Participant(displayName: "Kin"))
        let everyone = [yo.id, iori.id, liz.id, kin.id]
        let list = SharedList(
            name: "Hiking",
            participants: [yo, iori, liz, kin],
            defaultSplit: .equally(among: everyone))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let events: [ExpenseEvent] = [(Decimal(100), yo.id), (Decimal(400), iori.id), (Decimal(300), liz.id)]
            .map { amount, payer in
                .expenseAdded(ExpenseAdded(
                    amount: Money(amount: amount, currency: .mxn),
                    concept: "gasto",
                    category: "comida",
                    date: date,
                    paymentMethod: .cash,
                    sharedListID: list.id,
                    payer: payer,
                    split: .equally(among: everyone)))
            }
        let store = InMemorySharedListStore(seed: [list], events: events)
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: store,
            expenseStore: InMemoryExpenseStore(),
            parser: InMemoryExpenseParsing())
        await model.onAppear()
        await model.setViewer(yo.id)

        // Saldos: Yo −100, Iori +200, Liz +100, Kin −200. Yo le paga 2/3 a Iori.
        let debt = try #require(model.debts.first { $0.from == yo.id && $0.to == iori.id })
        #expect(debt.amount.amount == Decimal(string: "66.67"))
        let explanation = model.explanation(for: debt)
        #expect(explanation.debtorOwes.amount == 100)
        #expect(explanation.creditorCollects.amount == 200)
        #expect(explanation.totalOwed.amount == 300)
        #expect(explanation.creditorPercent == 67)
        #expect(explanation.debtorEntries.reduce(Decimal(0)) { $0 + $1.effect } == -100)
    }
}

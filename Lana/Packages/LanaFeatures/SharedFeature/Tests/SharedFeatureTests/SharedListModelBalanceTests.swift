import Foundation
import LanaCore
import Testing
@testable import SharedFeature

@Suite("SharedListModel — el saldo propio entre todas las listas")
@MainActor
struct SharedListModelBalanceTests {
    private let yo = Participant(displayName: "Dorian")
    private let renata = Participant(displayName: "Renata")

    private func list(_ name: String) -> SharedList {
        SharedList(
            name: name,
            participants: [yo, renata],
            defaultSplit: .equally(among: [yo.id, renata.id]))
    }

    /// Un gasto compartido que pagó `payer`, dividido a partes iguales.
    private func expense(_ amount: Decimal, in list: SharedList, payer: Participant) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "súper",
            category: "despensa",
            date: Date(),
            paymentMethod: .cash,
            sharedListID: list.id,
            payer: payer.id,
            split: .equally(among: [yo.id, renata.id])))
    }

    private func makeModel(
        lists: [SharedList],
        events: [ExpenseEvent],
        viewer: ParticipantID?) async -> SharedListModel {
        let store = InMemorySharedListStore(seed: lists)
        for event in events {
            await store.seedEvent(event)
        }
        if let viewer {
            for list in lists {
                try? await store.setViewerParticipantID(viewer, for: list.id)
            }
        }
        return SharedListModel(
            sharedListStore: store,
            expenseStore: InMemoryExpenseStore(),
            parser: InMemoryExpenseParsing())
    }

    @Test("Si pagaste tú, el saldo dice que te deben la mitad")
    func teDebenLaMitad() async {
        let baby = list("Baby")
        let model = await makeModel(lists: [baby], events: [expense(1000, in: baby, payer: yo)], viewer: yo.id)

        await model.onAppear()

        #expect(model.netBalance.first?.amount == 500)
    }

    @Test("Si pagó la otra persona, el saldo queda en contra")
    func debesLaMitad() async {
        let baby = list("Baby")
        let model = await makeModel(lists: [baby], events: [expense(1000, in: baby, payer: renata)], viewer: yo.id)

        await model.onAppear()

        #expect(model.netBalance.first?.amount == -500)
    }

    @Test("El saldo suma todas las listas, no una sola")
    func sumaTodasLasListas() async {
        let baby = list("Baby")
        let viaje = list("Viaje")
        let model = await makeModel(
            lists: [baby, viaje],
            events: [expense(1000, in: baby, payer: yo), expense(400, in: viaje, payer: yo)],
            viewer: yo.id)

        await model.onAppear()

        #expect(model.netBalance.count == 1)
        #expect(model.netBalance.first?.amount == 700)
    }

    @Test("Sin identidad marcada en la lista, no se inventa un saldo propio")
    func sinIdentidadNoHaySaldo() async {
        let baby = list("Baby")
        let model = await makeModel(lists: [baby], events: [expense(1000, in: baby, payer: yo)], viewer: nil)

        await model.onAppear()

        #expect(model.netBalance.isEmpty)
    }

    @Test("Las deudas que se muestran son las que te involucran")
    func deudasQueTeInvolucran() async {
        let baby = list("Baby")
        let model = await makeModel(lists: [baby], events: [expense(1000, in: baby, payer: yo)], viewer: yo.id)

        await model.onAppear()

        let debts = model.debtsInvolvingViewer(in: baby)
        #expect(debts.count == 1)
        #expect(debts.first?.from == renata.id)
        #expect(debts.first?.to == yo.id)
    }
}

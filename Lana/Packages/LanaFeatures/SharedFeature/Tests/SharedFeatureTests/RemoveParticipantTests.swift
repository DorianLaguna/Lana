import Foundation
import LanaCore
import Testing
@testable import SharedFeature

@Suite("Quitar a alguien de una lista (ADR-0052)")
@MainActor
struct RemoveParticipantTests {
    let yo = Participant(displayName: "Yo")
    let iori = Participant(displayName: "Iori")
    let liz = Participant(displayName: "Liz")
    let kin = Participant(displayName: "Kin")

    private func makeModel() async -> (SharedListDetailModel, InMemoryExpenseStore) {
        let expenseStore = InMemoryExpenseStore()
        let list = SharedList(
            name: "Hiking",
            participants: [yo, iori, liz, kin],
            defaultSplit: .equally(among: [yo.id, iori.id, liz.id, kin.id]))
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: expenseStore,
            parser: InMemoryExpenseParsing())
        await model.onAppear()
        await model.setViewer(yo.id)
        return (model, expenseStore)
    }

    @Test("Quien solo aparece en partes iguales se puede quitar, y sale de esos gastos")
    func seQuitaDePartesIguales() async throws {
        let (model, store) = await makeModel()
        _ = await model.recordExpense(
            amount: money(400),
            concept: "tacos",
            date: .now,
            payer: yo.id,
            split: .equally(among: [yo.id, iori.id, liz.id, kin.id]))

        #expect(model.removalBlocker(for: liz.id) == nil)
        #expect(model.expensesToExclude([liz.id]).count == 1)
        #expect(await model.exclude([liz.id]))

        let tacos = try #require(try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
            .first)
        #expect(tacos.split == .equally(among: [yo.id, iori.id, kin.id]))
        #expect(model.debts.allSatisfy { $0.from != liz.id && $0.to != liz.id })
    }

    @Test("No se puede quitar a quien pagó, liquidó, está en otra división o eres tú")
    func bloqueos() async {
        let (model, _) = await makeModel()
        _ = await model.recordExpense(
            amount: money(100),
            concept: "agua",
            date: .now,
            payer: iori.id,
            split: .equally(among: [yo.id, iori.id]))
        _ = await model.recordExpense(
            amount: money(100),
            concept: "gasolina",
            date: .now,
            payer: yo.id,
            split: .exactAmounts(amounts: [yo.id: 70, kin.id: 30]))

        #expect(model.removalBlocker(for: yo.id) == "Eres tú en esta lista.")
        #expect(model.removalBlocker(for: iori.id) == "Pagó gastos en esta lista.")
        #expect(model.removalBlocker(for: kin.id) == "Está en gastos divididos por porcentaje o montos.")
        #expect(model.removalBlocker(for: liz.id) == nil)

        _ = await model.recordSettlement(from: liz.id, to: yo.id, amount: 20, currency: .mxn, date: .now)
        #expect(model.removalBlocker(for: liz.id) == "Tiene pagos registrados en esta lista.")
    }

    private func money(_ amount: Decimal) -> Money {
        Money(amount: amount, currency: .mxn)
    }

    @Test("La edición reporta a quién se quitó y respeta los bloqueos")
    func edicionReportaQuitados() async {
        let (model, _) = await makeModel()
        var saved: SharedListEdit?
        let edit = EditSharedListModel(
            list: model.list,
            viewerID: yo.id,
            removalBlocker: { $0 == iori.id ? "Pagó gastos en esta lista." : nil },
            onSave: { saved = $0
                return true
            })
        let rows = edit.participants
        edit.addParticipant()
        let newcomer = try? #require(edit.participants.last)

        edit.remove(rows[1]) // Iori: bloqueado
        edit.remove(rows[2]) // Liz
        if let newcomer {
            edit.remove(newcomer) // recién agregado: no cuenta como quitado
        }
        #expect(await edit.save())

        #expect(saved?.removed == [liz.id])
        #expect(saved?.list.participants.map(\.id) == [yo.id, iori.id, kin.id])
    }
}

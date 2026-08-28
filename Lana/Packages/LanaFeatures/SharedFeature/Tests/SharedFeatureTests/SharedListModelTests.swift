import Foundation
import LanaCore
import Testing
@testable import SharedFeature

@Suite("SharedListModel")
@MainActor
struct SharedListModelTests {
    @Test("onAppear carga las listas ya guardadas")
    func onAppearCargaLasListasYaGuardadas() async {
        let list = SharedList(name: "Depa", participants: [Participant(displayName: "Alice")], defaultSplit: .payerOnly)
        let model = SharedListModel(
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: InMemoryExpenseStore())

        await model.onAppear()

        #expect(model.lists.map(\.name) == ["Depa"])
    }

    @Test("Borrar quita la lista de la lista de listas")
    func borrarQuitaLaListaDeLaListaDeListas() async {
        let list = SharedList(name: "Depa", participants: [Participant(displayName: "Alice")], defaultSplit: .payerOnly)
        let model = SharedListModel(
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: InMemoryExpenseStore())
        await model.onAppear()

        await model.delete(list)

        #expect(model.lists.isEmpty)
    }
}

@Suite("CreateSharedListModel")
@MainActor
struct CreateSharedListModelTests {
    @Test("Crear con nombre y 2+ participantes guarda la lista con split default en partes iguales")
    func crearConNombreYParticipantesGuardaLaLista() async {
        let store = InMemorySharedListStore()
        let model = CreateSharedListModel(sharedListStore: store)
        model.name = "Depa"
        model.participantNames = ["Alice", "Bob"]

        let saved = await model.save()

        #expect(saved)
        let lists = try? await store.lists()
        #expect(lists?.first?.name == "Depa")
        #expect(lists?.first?.participants.map(\.displayName).sorted() == ["Alice", "Bob"])
        if case .equally = lists?.first?.defaultSplit {
            // esperado
        } else {
            Issue.record("El split default debería ser .equally")
        }
    }

    @Test("Sin nombre no guarda y deja ver el error")
    func sinNombreNoGuarda() async {
        let model = CreateSharedListModel(sharedListStore: InMemorySharedListStore())
        model.participantNames = ["Alice", "Bob"]

        let saved = await model.save()

        #expect(!saved)
        #expect(model.errorMessage != nil)
    }

    @Test("Con menos de 2 participantes no guarda y deja ver el error")
    func conMenosDeDosParticipantesNoGuarda() async {
        let model = CreateSharedListModel(sharedListStore: InMemorySharedListStore())
        model.name = "Depa"
        model.participantNames = ["Alice", ""]

        let saved = await model.save()

        #expect(!saved)
        #expect(model.errorMessage != nil)
    }

    @Test("removeParticipant no baja de 2 casillas")
    func removeParticipantNoBajaDeDosCasillas() {
        let model = CreateSharedListModel(sharedListStore: InMemorySharedListStore())
        #expect(model.participantNames.count == 2)

        model.removeParticipant(at: 0)

        #expect(model.participantNames.count == 2)
    }
}

@Suite("SharedListDetailModel")
@MainActor
struct SharedListDetailModelTests {
    let alice = Participant(displayName: "Alice")
    let bob = Participant(displayName: "Bob")
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func expenseAdded(
        amount: Decimal,
        payer: ParticipantID,
        split: SplitRule,
        sharedListID: SharedListID,
        recordedAt: Date) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "gasto",
            category: "otros",
            date: recordedAt,
            paymentMethod: .cash,
            sharedListID: sharedListID,
            payer: payer,
            split: split,
            recordedAt: recordedAt))
    }

    @Test("recordExpense guarda el gasto en el ExpenseStore con sharedListID/payer/split")
    func recordExpenseGuardaElGastoConLosCamposCompartidos() async throws {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let expenseStore = InMemoryExpenseStore()
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list]),
            expenseStore: expenseStore)

        let saved = await model.recordExpense(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            date: .now,
            payer: alice.id,
            split: .equally(among: [alice.id, bob.id]))

        #expect(saved)
        let expenses = try await expenseStore.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(expenses.count == 1)
        #expect(expenses.first?.sharedListID == list.id)
        #expect(expenses.first?.payer == alice.id)
        #expect(expenses.first?.split == .equally(among: [alice.id, bob.id]))
    }

    @Test("Partes iguales entre 2 personas da el mismo saldo que PersonLedgerTests")
    func partesIgualesEntreDosPersonasDaElSaldoEsperado() async {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let event = expenseAdded(
            amount: 100, payer: alice.id, split: .equally(among: [alice.id, bob.id]),
            sharedListID: list.id, recordedAt: referenceDate)
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list], events: [event]),
            expenseStore: InMemoryExpenseStore())

        await model.onAppear(asOf: referenceDate)

        let aliceBalance = model.balances.first { $0.participant.id == alice.id }
        let bobBalance = model.balances.first { $0.participant.id == bob.id }
        #expect(aliceBalance?.amount == 50)
        #expect(bobBalance?.amount == -50)
        #expect(model.debts.first?.from == bob.id)
        #expect(model.debts.first?.to == alice.id)
        #expect(model.debts.first?.amount.amount == 50)
    }

    @Test("4 personas con split proporcional: la suma de saldos sigue siendo cero")
    func cuatroPersonasProporcionalSumaCero() async throws {
        let carol = Participant(displayName: "Carol")
        let dana = Participant(displayName: "Dana")
        let list = SharedList(name: "Viaje", participants: [alice, bob, carol, dana], defaultSplit: .payerOnly)
        let split = try SplitRule.proportional(shares: [
            alice.id: #require(Decimal(string: "0.4")),
            bob.id: #require(Decimal(string: "0.3")),
            carol.id: #require(Decimal(string: "0.2")),
            dana.id: #require(Decimal(string: "0.1"))
        ])
        let event = expenseAdded(
            amount: 1000,
            payer: alice.id,
            split: split,
            sharedListID: list.id,
            recordedAt: referenceDate)
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list], events: [event]),
            expenseStore: InMemoryExpenseStore())

        await model.onAppear(asOf: referenceDate)

        let sum = model.balances.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(sum == 0)
        #expect(model.balances.count == 4)
    }

    @Test("Liquidar reduce el saldo exactamente el monto pagado, no lo elimina de golpe")
    func liquidarReduceElSaldoExactamenteElMontoPagado() async {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let event = expenseAdded(
            amount: 100, payer: alice.id, split: .equally(among: [alice.id, bob.id]),
            sharedListID: list.id, recordedAt: referenceDate)
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list], events: [event]),
            expenseStore: InMemoryExpenseStore())
        await model.onAppear(asOf: referenceDate)

        let settled = await model.recordSettlement(
            from: bob.id,
            to: alice.id,
            amount: 20,
            currency: .mxn,
            date: referenceDate)

        #expect(settled)
        let aliceBalance = model.balances.first { $0.participant.id == alice.id }
        let bobBalance = model.balances.first { $0.participant.id == bob.id }
        #expect(aliceBalance?.amount == 30)
        #expect(bobBalance?.amount == -30)
    }

    @Test("Liquidar toda la deuda deja el saldo en cero — desaparece de la lista de saldos")
    func liquidarTodaLaDeudaDejaElSaldoEnCero() async {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let event = expenseAdded(
            amount: 100, payer: alice.id, split: .equally(among: [alice.id, bob.id]),
            sharedListID: list.id, recordedAt: referenceDate)
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list], events: [event]),
            expenseStore: InMemoryExpenseStore())
        await model.onAppear(asOf: referenceDate)

        let settled = await model.recordSettlement(
            from: bob.id,
            to: alice.id,
            amount: 50,
            currency: .mxn,
            date: referenceDate)

        #expect(settled)
        #expect(model.balances.isEmpty)
        #expect(model.debts.isEmpty)
    }

    @Test("Un saldo que no existía hace 30 días marca tendencia creciente")
    func unSaldoQueNoExistiaHace30DiasMarcaTendenciaCreciente() async {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let event = expenseAdded(
            amount: 100, payer: alice.id, split: .equally(among: [alice.id, bob.id]),
            sharedListID: list.id, recordedAt: referenceDate)
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list], events: [event]),
            expenseStore: InMemoryExpenseStore())

        await model.onAppear(asOf: referenceDate)

        #expect(model.balances.allSatisfy { $0.trend == .growing })
    }

    @Test("Un saldo grabado hace más de 30 días, sin cambios recientes, marca tendencia estable")
    func unSaldoGrabadoHaceMasDe30DiasSinCambiosMarcaEstable() async {
        let list = SharedList(
            name: "Depa",
            participants: [alice, bob],
            defaultSplit: .equally(among: [alice.id, bob.id]))
        let oldDate = referenceDate.addingTimeInterval(-60 * 24 * 60 * 60)
        let event = expenseAdded(
            amount: 100, payer: alice.id, split: .equally(among: [alice.id, bob.id]),
            sharedListID: list.id, recordedAt: oldDate)
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: InMemorySharedListStore(seed: [list], events: [event]),
            expenseStore: InMemoryExpenseStore())

        await model.onAppear(asOf: referenceDate)

        #expect(model.balances.allSatisfy { $0.trend == .stable })
    }
}

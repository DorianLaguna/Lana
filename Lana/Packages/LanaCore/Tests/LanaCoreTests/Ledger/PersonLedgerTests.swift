import Foundation
import Testing
@testable import LanaCore

@Suite("PersonLedger")
struct PersonLedgerTests {
    let listID = SharedListID()
    let alice = ParticipantID()
    let bob = ParticipantID()
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func expenseAdded(
        amount: Decimal,
        payer: ParticipantID,
        split: SplitRule,
        recordedAt: Date) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "gasto",
            category: "otros",
            date: referenceDate,
            paymentMethod: .cash,
            sharedListID: listID,
            payer: payer,
            split: split,
            recordedAt: recordedAt))
    }

    @Test("Split en partes iguales entre 2 personas")
    func saldoBasicoDosPersonas() {
        let ledger = PersonLedger(events: [
            expenseAdded(amount: 100, payer: alice, split: .equally(among: [alice, bob]), recordedAt: referenceDate)
        ])
        let balances = ledger.netBalances(in: listID)[.mxn] ?? [:]
        #expect(balances[alice] == 50)
        #expect(balances[bob] == -50)
    }

    @Test("Una corrección de monto actualiza el saldo derivado")
    func correccionActualizaSaldo() {
        let added = expenseAdded(
            amount: 100,
            payer: alice,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate)
        let correction = ExpenseCorrected(
            correctsEventID: added.id,
            amount: Money(amount: 200, currency: .mxn),
            recordedAt: referenceDate.addingTimeInterval(60))
        let ledger = PersonLedger(events: [added, .expenseCorrected(correction)])

        let balances = ledger.netBalances(in: listID)[.mxn] ?? [:]
        #expect(balances[alice] == 100)
        #expect(balances[bob] == -100)
    }

    @Test("Anular un gasto lo excluye del saldo, sin afectar los demás")
    func anulacionExcluyeSoloEseGasto() {
        let baseline = expenseAdded(
            amount: 100,
            payer: alice,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate)
        let toVoid = expenseAdded(
            amount: 50,
            payer: alice,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate)
        let void = ExpenseVoided(voidsEventID: toVoid.id, recordedAt: referenceDate.addingTimeInterval(60))

        let ledger = PersonLedger(events: [baseline, toVoid, .expenseVoided(void)])

        let balances = ledger.netBalances(in: listID)[.mxn] ?? [:]
        #expect(balances[alice] == 50)
        #expect(balances[bob] == -50)
    }

    @Test("Una liquidación reduce el saldo, no lo elimina de golpe")
    func liquidacionReduceSaldo() {
        let added = expenseAdded(
            amount: 100,
            payer: alice,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate)
        let settlement = SettlementRecorded(
            sharedListID: listID,
            from: bob,
            to: alice,
            amount: Money(amount: 20, currency: .mxn),
            paymentMethod: .transfer,
            date: referenceDate.addingTimeInterval(3600))
        let ledger = PersonLedger(events: [added, .settlementRecorded(settlement)])

        let balances = ledger.netBalances(in: listID)[.mxn] ?? [:]
        #expect(balances[alice] == 30)
        #expect(balances[bob] == -30)
    }

    @Test("4 personas con split proporcional: la suma de saldos siempre es cero")
    func cuatroPersonasProporcionalSumaCero() throws {
        let carol = ParticipantID()
        let dana = ParticipantID()
        let split = try SplitRule.proportional(shares: [
            alice: #require(Decimal(string: "0.4")),
            bob: #require(Decimal(string: "0.3")),
            carol: #require(Decimal(string: "0.2")),
            dana: #require(Decimal(string: "0.1"))
        ])
        let ledger = PersonLedger(events: [
            expenseAdded(amount: 1000, payer: alice, split: split, recordedAt: referenceDate)
        ])

        let balances = ledger.netBalances(in: listID)[.mxn] ?? [:]
        let sum = balances.values.reduce(Decimal(0), +)
        #expect(sum == 0)
        #expect(try #require(balances[alice]) > 0)
        #expect(try #require(balances[bob]) < 0)
    }

    @Test("simplifiedDebts salda exactamente los saldos netos, sin sobrantes")
    func simplificacionSaldaLosNetos() {
        let carol = ParticipantID()
        let events: [ExpenseEvent] = [
            expenseAdded(
                amount: 300,
                payer: alice,
                split: .equally(among: [alice, bob, carol]),
                recordedAt: referenceDate),
            expenseAdded(amount: 90, payer: bob, split: .equally(among: [alice, bob, carol]), recordedAt: referenceDate)
        ]
        let ledger = PersonLedger(events: events)
        let netBefore = ledger.netBalances(in: listID)[.mxn] ?? [:]
        let debts = ledger.simplifiedDebts(in: listID, currency: .mxn)

        var netAfterSettling = netBefore
        for debt in debts {
            netAfterSettling[debt.from, default: 0] += debt.amount.amount
            netAfterSettling[debt.to, default: 0] -= debt.amount.amount
        }
        for balance in netAfterSettling.values {
            #expect(balance == 0)
        }
    }

    @Test("El orden de los eventos no cambia el saldo final (ADR-0005)")
    func eventosConmutanOrdenNoImporta() {
        let added = expenseAdded(
            amount: 300,
            payer: alice,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate)
        let correction = ExpenseCorrected(
            correctsEventID: added.id,
            amount: Money(amount: 150, currency: .mxn),
            recordedAt: referenceDate.addingTimeInterval(60))
        let settlement = SettlementRecorded(
            sharedListID: listID,
            from: bob,
            to: alice,
            amount: Money(amount: 10, currency: .mxn),
            paymentMethod: .transfer,
            date: referenceDate.addingTimeInterval(120))
        let events: [ExpenseEvent] = [added, .expenseCorrected(correction), .settlementRecorded(settlement)]

        let inOrder = PersonLedger(events: events).netBalances(in: listID)[.mxn] ?? [:]
        let reversed = PersonLedger(events: events.reversed()).netBalances(in: listID)[.mxn] ?? [:]
        let shuffled = PersonLedger(events: [events[2], events[0], events[1]]).netBalances(in: listID)[.mxn] ?? [:]

        #expect(inOrder == reversed)
        #expect(inOrder == shuffled)
        #expect(inOrder[alice] == 65)
        #expect(inOrder[bob] == -65)
    }

    @Test("Gastos en monedas distintas nunca se mezclan en un mismo saldo")
    func monedasSeparadasNuncaSeMezclan() {
        let mxnExpense = expenseAdded(
            amount: 100,
            payer: alice,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate)
        let usdExpense = ExpenseEvent.expenseAdded(ExpenseAdded(
            amount: Money(amount: 100, currency: .usd),
            concept: "gasto en danaólares",
            category: "otros",
            date: referenceDate,
            paymentMethod: .cash,
            sharedListID: listID,
            payer: alice,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate))
        let ledger = PersonLedger(events: [mxnExpense, usdExpense])

        let balances = ledger.netBalances(in: listID)
        #expect(balances[.mxn]?[alice] == 50)
        #expect(balances[.usd]?[alice] == 50)
    }
}

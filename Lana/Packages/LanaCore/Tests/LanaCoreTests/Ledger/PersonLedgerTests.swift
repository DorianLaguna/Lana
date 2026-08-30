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

    @Test("contributions detalla gasto por gasto entre dos personas, con su suma igual al saldo neto de `to`")
    func contributionsSumaIgualAlSaldoNetoDeTo() {
        // Fechas distintas (no solo `recordedAt`) para que el orden
        // cronológico de `contributions` sea inequívoco — el helper
        // `expenseAdded` fija `date: referenceDate` siempre.
        let firstDate = referenceDate
        let secondDate = referenceDate.addingTimeInterval(86400)
        let events: [ExpenseEvent] = [
            .expenseAdded(ExpenseAdded(
                amount: Money(amount: 100, currency: .mxn),
                concept: "renta",
                category: "hogar",
                date: firstDate,
                paymentMethod: .cash,
                sharedListID: listID,
                payer: alice,
                split: .equally(among: [alice, bob]),
                recordedAt: firstDate)),
            .expenseAdded(ExpenseAdded(
                amount: Money(amount: 40, currency: .mxn),
                concept: "internet",
                category: "hogar",
                date: secondDate,
                paymentMethod: .cash,
                sharedListID: listID,
                payer: bob,
                split: .equally(among: [alice, bob]),
                recordedAt: secondDate))
        ]
        let ledger = PersonLedger(events: events)
        // from: alice, to: bob — el primer gasto lo pagó alice (bob le debe
        // su mitad, `signedEffect` negativo: no aumenta lo que alice le debe
        // a bob, lo reduce); el segundo lo pagó bob (sí aumenta lo que
        // alice le debe a bob, positivo).
        let contributions = ledger.contributions(between: alice, and: bob, in: listID)

        #expect(contributions.count == 2)
        #expect(contributions[0].signedEffect == -50)
        #expect(contributions[1].signedEffect == 20)

        let bobNetBalance = ledger.netBalances(in: listID)[.mxn]?[bob] ?? 0
        let contributionsSum = contributions.reduce(Decimal(0)) { $0 + $1.signedEffect }
        #expect(contributionsSum == bobNetBalance)
    }

    @Test("contributions ignora un tercer participante ajeno al par consultado")
    func contributionsIgnoraTercerParticipante() throws {
        let carol = ParticipantID()
        // `.proportional` con fracciones exactas (0.5/0.3/0.2) en vez de
        // `.equally` entre 3 — 1/3 no termina en `Decimal`, y el residuo de
        // redondeo se lo queda quien ordene último por `ParticipantID`
        // (aleatorio en cada corrida), lo que haría este test inestable.
        let split = try SplitRule.proportional(shares: [
            alice: #require(Decimal(string: "0.5")),
            bob: #require(Decimal(string: "0.3")),
            carol: #require(Decimal(string: "0.2"))
        ])
        let ledger = PersonLedger(events: [
            expenseAdded(amount: 1000, payer: alice, split: split, recordedAt: referenceDate)
        ])
        let contributions = ledger.contributions(between: alice, and: bob, in: listID)

        #expect(contributions.count == 1)
        #expect(contributions[0].fromShare.amount == 500)
        #expect(contributions[0].toShare.amount == 300)
        #expect(contributions[0].signedEffect == -300)
    }

    @Test("Un gasto payerOnly nunca contribuye — nadie más debe nada de él")
    func contributionsExcluyePayerOnly() {
        let ledger = PersonLedger(events: [
            expenseAdded(amount: 500, payer: alice, split: .payerOnly, recordedAt: referenceDate)
        ])
        let contributions = ledger.contributions(between: alice, and: bob, in: listID)

        #expect(contributions.isEmpty)
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

import Foundation
import Testing
@testable import LanaCore

@Suite("PersonLedger.directDebts (ADR-0051)")
struct DirectDebtsTests {
    let listID = SharedListID()
    let yo = ParticipantID()
    let iori = ParticipantID()
    let kin = ParticipantID()
    let fernando = ParticipantID()

    private func expense(_ amount: Decimal, payer: ParticipantID, among: [ParticipantID]) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "gasto",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            paymentMethod: .cash,
            sharedListID: listID,
            payer: payer,
            split: .equally(among: among)))
    }

    private func debt(_ debts: [Debt], from: ParticipantID, to: ParticipantID) -> Decimal? {
        debts.first { $0.from == from && $0.to == to }?.amount.amount
    }

    @Test("Cada quien le debe a cada persona que pagó su parte de lo que pagó, neto entre los dos")
    func deudasDirectas() {
        let everyone = [yo, iori, kin, fernando]
        let ledger = PersonLedger(events: [
            expense(400, payer: yo, among: everyone),
            expense(200, payer: iori, among: everyone)
        ])

        let debts = ledger.directDebts(in: listID, currency: .mxn)

        // Kin y Fernando le deben a los dos, no a uno solo.
        #expect(debt(debts, from: kin, to: yo) == 100)
        #expect(debt(debts, from: kin, to: iori) == 50)
        #expect(debt(debts, from: fernando, to: yo) == 100)
        #expect(debt(debts, from: fernando, to: iori) == 50)
        // Entre Iori y yo se netea: él me debe 100, yo le debo 50.
        #expect(debt(debts, from: iori, to: yo) == 50)
        #expect(debt(debts, from: yo, to: iori) == nil)
        #expect(debts.count == 5)
    }

    @Test("Saldan exactamente los saldos netos de cada quien")
    func saldanLosNetos() {
        let everyone = [yo, iori, kin, fernando]
        let ledger = PersonLedger(events: [
            expense(350, payer: yo, among: everyone),
            expense(Decimal(string: "182.5") ?? 0, payer: iori, among: everyone),
            expense(50, payer: kin, among: [yo, kin])
        ])
        var net = ledger.netBalances(in: listID)[.mxn] ?? [:]
        for debt in ledger.directDebts(in: listID, currency: .mxn) {
            net[debt.from, default: 0] += debt.amount.amount
            net[debt.to, default: 0] -= debt.amount.amount
        }
        #expect(net.values.allSatisfy { $0 == 0 })
    }

    @Test("Una liquidación descuenta solo de ese par")
    func liquidacionDescuentaDelPar() {
        let ledger = PersonLedger(events: [
            expense(300, payer: yo, among: [yo, kin, iori]),
            .settlementRecorded(SettlementRecorded(
                sharedListID: listID,
                from: kin,
                to: yo,
                amount: Money(amount: 60, currency: .mxn),
                paymentMethod: .cash,
                date: Date(timeIntervalSince1970: 1_700_000_000)))
        ])

        let debts = ledger.directDebts(in: listID, currency: .mxn)

        #expect(debt(debts, from: kin, to: yo) == 40)
        #expect(debt(debts, from: iori, to: yo) == 100)
    }
}

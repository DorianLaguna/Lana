import Foundation
import Testing
@testable import LanaCore

@Suite("PersonLedger.settlementPlan (ADR-0053)")
struct SettlementPlanTests {
    let listID = SharedListID()
    let people = (0 ..< 8).map { _ in ParticipantID() }

    private func expense(_ text: String, payer: ParticipantID, among: [ParticipantID]) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: Decimal(string: text) ?? 0, currency: .mxn),
            concept: "gasto",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            paymentMethod: .cash,
            sharedListID: listID,
            payer: payer,
            split: .equally(among: among)))
    }

    /// Como la lista del reporte: ocho personas, pagan tres, y quien más pagó
    /// de los tres todavía queda debiendo.
    private var ledger: PersonLedger {
        let (yo, iori, liz) = (people[0], people[1], people[2])
        return PersonLedger(events: [
            expense("350", payer: yo, among: people),
            expense("50", payer: yo, among: people),
            expense("696", payer: iori, among: people),
            expense("512.8", payer: liz, among: people),
            expense("32", payer: yo, among: people)
        ])
    }

    @Test("Cada quien paga o cobra exactamente su saldo, al centavo")
    func cuadraConLosSaldos() {
        let balances = ledger.netBalances(in: listID)[.mxn] ?? [:]
        let plan = ledger.settlementPlan(in: listID, currency: .mxn)

        for (participant, balance) in balances {
            let paid = plan.filter { $0.from == participant }.reduce(Decimal(0)) { $0 + $1.amount.amount }
            let received = plan.filter { $0.to == participant }.reduce(Decimal(0)) { $0 + $1.amount.amount }
            #expect(received - paid == balance, "saldo \(balance), recibe \(received), paga \(paid)")
            // Nadie paga y cobra a la vez.
            #expect(paid == 0 || received == 0)
        }
    }

    @Test("Quienes compartieron lo mismo le deben lo mismo a cada quien")
    func simetrico() {
        let plan = ledger.settlementPlan(in: listID, currency: .mxn)
        let nonPayers = Array(people[3...])
        for creditor in Set(plan.map(\.to)) {
            let amounts = nonPayers.compactMap { debtor in
                plan.first { $0.from == debtor && $0.to == creditor }?.amount.amount
            }
            #expect(amounts.count == nonPayers.count)
            let spread = (amounts.max() ?? 0) - (amounts.min() ?? 0)
            #expect(spread <= Decimal(string: "0.02") ?? 0, "\(amounts)")
        }
    }

    @Test("Los movimientos de un participante suman su saldo")
    func movimientosSumanElSaldo() {
        let balances = ledger.netBalances(in: listID)[.mxn] ?? [:]
        for participant in people {
            let entries = ledger.balanceEntries(for: participant, in: listID, currency: .mxn)
            #expect(entries.reduce(Decimal(0)) { $0 + $1.effect } == (balances[participant] ?? 0))
        }
    }

    @Test("Una liquidación registrada baja lo que falta, sin descuadrar")
    func liquidacionBajaElPlan() throws {
        let first = try #require(ledger.settlementPlan(in: listID, currency: .mxn).first)
        let settled = ledger.appending(.settlementRecorded(SettlementRecorded(
            sharedListID: listID,
            from: first.from,
            to: first.to,
            amount: first.amount,
            paymentMethod: .cash,
            date: Date(timeIntervalSince1970: 1_700_000_000))))

        let plan = settled.settlementPlan(in: listID, currency: .mxn)
        let balances = settled.netBalances(in: listID)[.mxn] ?? [:]
        let owedByFirst = plan.filter { $0.from == first.from }.reduce(Decimal(0)) { $0 + $1.amount.amount }
        #expect(owedByFirst == -(balances[first.from] ?? 0))
    }
}

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

    private func settling(_ debt: Debt, on ledger: PersonLedger) -> PersonLedger {
        ledger.appending(.settlementRecorded(SettlementRecorded(
            sharedListID: listID,
            from: debt.from,
            to: debt.to,
            amount: debt.amount,
            paymentMethod: .cash,
            date: Date(timeIntervalSince1970: 1_700_000_000))))
    }

    @Test("Pagar una fila completa la cierra y no mueve las demás (ADR-0054)")
    func pagarUnaFilaLaCierra() throws {
        let before = ledger.settlementPlan(in: listID, currency: .mxn)
        let paid = try #require(before.first)

        let after = settling(paid, on: ledger).settlementPlan(in: listID, currency: .mxn)

        #expect(!after.contains { $0.from == paid.from && $0.to == paid.to })
        let untouched = before.filter { !($0.from == paid.from && $0.to == paid.to) }
        #expect(after == untouched)
    }

    @Test("Pagar todo lo de una persona la saca del plan y la deja en cero")
    func pagarTodoLoDeUnaPersona() throws {
        var current = ledger
        let debtor = try #require(ledger.settlementPlan(in: listID, currency: .mxn).first?.from)
        for debt in ledger.settlementPlan(in: listID, currency: .mxn) where debt.from == debtor {
            current = settling(debt, on: current)
        }

        #expect(!current.settlementPlan(in: listID, currency: .mxn).contains { $0.from == debtor })
        #expect((current.netBalances(in: listID)[.mxn] ?? [:])[debtor] == 0)
    }

    /// El caso del reporte: la lista ya traía pagos registrados con el reparto
    /// anterior, y pagar una fila movía también la del otro acreedor.
    @Test("Con pagos viejos que no cuadran, pagar una fila no mueve las demás (ADR-0054)")
    func pagosViejosNoContagianLasDemasFilas() throws {
        let iori = people[1]
        // Un pago del reparto anterior: alguien le pagó todo su saldo a Iori.
        var current = ledger.appending(.settlementRecorded(SettlementRecorded(
            sharedListID: listID,
            from: people[3],
            to: iori,
            amount: Money(amount: 200, currency: .mxn),
            paymentMethod: .cash,
            date: Date(timeIntervalSince1970: 1_700_000_000))))

        let before = current.settlementPlan(in: listID, currency: .mxn)
        let paid = try #require(before.first { $0.from == people[4] })
        let others = before.filter { !($0.from == paid.from && $0.to == paid.to) }

        current = settling(paid, on: current)
        let after = current.settlementPlan(in: listID, currency: .mxn)

        #expect(!after.contains { $0.from == paid.from && $0.to == paid.to })
        #expect(after == others)

        // Y sigue cuadrando con los saldos.
        let balances = current.netBalances(in: listID)[.mxn] ?? [:]
        for (participant, balance) in balances {
            let paidTotal = after.filter { $0.from == participant }.reduce(Decimal(0)) { $0 + $1.amount.amount }
            let received = after.filter { $0.to == participant }.reduce(Decimal(0)) { $0 + $1.amount.amount }
            #expect(received - paidTotal == balance)
        }
    }

    @Test("Pagar de más no descuadra el plan: se parcha la diferencia")
    func pagarDeMasNoDescuadra() throws {
        let plan = ledger.settlementPlan(in: listID, currency: .mxn)
        let debtor = try #require(plan.first?.from)
        // Le paga de más a quien sí le tocaba: el plan deja de corresponder.
        let excessive = try Debt(
            from: debtor,
            to: #require(plan.first?.to),
            amount: Money(amount: 5000, currency: .mxn))
        let after = settling(excessive, on: ledger)

        let balances = after.netBalances(in: listID)[.mxn] ?? [:]
        for debt in after.settlementPlan(in: listID, currency: .mxn) {
            #expect(debt.amount.amount > 0)
        }
        for (participant, balance) in balances {
            let plan = after.settlementPlan(in: listID, currency: .mxn)
            let paid = plan.filter { $0.from == participant }.reduce(Decimal(0)) { $0 + $1.amount.amount }
            let received = plan.filter { $0.to == participant }.reduce(Decimal(0)) { $0 + $1.amount.amount }
            #expect(received - paid == balance)
        }
    }
}

import Foundation
import Testing
@testable import LanaCore

@Suite("ExpenseProjection")
struct ExpenseProjectionTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Un gasto sin correcciones se proyecta tal cual")
    func gastoSinCorreccionesSeProyectaTalCual() {
        let added = ExpenseAdded(
            amount: Money(amount: 100, currency: .mxn),
            concept: "café",
            category: "comida",
            date: referenceDate,
            paymentMethod: .cash)
        let expenses = ExpenseProjection.expenses(from: [.expenseAdded(added)])

        #expect(expenses.count == 1)
        #expect(expenses.first?.id.rawValue == added.id.rawValue)
        #expect(expenses.first?.concept == "café")
        #expect(expenses.first?.category == "comida")
    }

    @Test("Una corrección de concepto y categoría se refleja en la proyección")
    func correccionSeReflejaEnLaProyeccion() {
        let added = ExpenseAdded(
            amount: Money(amount: 100, currency: .mxn),
            concept: "café",
            category: "comida",
            date: referenceDate,
            paymentMethod: .cash)
        let correction = ExpenseCorrected(
            correctsEventID: added.id,
            concept: "café con Ana",
            category: "social",
            recordedAt: referenceDate.addingTimeInterval(60))
        let expenses = ExpenseProjection.expenses(from: [.expenseAdded(added), .expenseCorrected(correction)])

        #expect(expenses.count == 1)
        #expect(expenses.first?.concept == "café con Ana")
        #expect(expenses.first?.category == "social")
    }

    @Test("Un gasto anulado no aparece en la proyección")
    func gastoAnuladoNoAparece() {
        let added = ExpenseAdded(
            amount: Money(amount: 100, currency: .mxn),
            concept: "café",
            category: "comida",
            date: referenceDate,
            paymentMethod: .cash)
        let void = ExpenseVoided(voidsEventID: added.id)
        let expenses = ExpenseProjection.expenses(from: [.expenseAdded(added), .expenseVoided(void)])

        #expect(expenses.isEmpty)
    }

    @Test("Un pago de tarjeta nunca aparece como transacción")
    func pagoDeTarjetaNuncaAparece() {
        let payment = CardPaymentRecorded(
            cardID: CardID(),
            amount: Money(amount: 300, currency: .mxn),
            date: referenceDate)
        let expenses = ExpenseProjection.expenses(from: [.cardPaymentRecorded(payment)])

        #expect(expenses.isEmpty)
    }

    @Test("Un ingreso se proyecta sin categoría")
    func ingresoSeProyectaSinCategoria() {
        let added = IncomeAdded(amount: Money(amount: 5000, currency: .mxn), concept: "nómina", date: referenceDate)
        let expenses = ExpenseProjection.expenses(from: [.incomeAdded(added)])

        #expect(expenses.first?.kind == .income)
        #expect(expenses.first?.category == nil)
    }
}

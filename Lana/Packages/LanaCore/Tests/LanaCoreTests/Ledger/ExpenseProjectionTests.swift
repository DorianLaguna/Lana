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

    @Test("Una corrección sí cambia quién pagó y cómo se divide (ADR-0023)")
    func correccionCambiaPagadorYSplit() {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let listID = SharedListID()
        let added = ExpenseAdded(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            category: "hogar",
            date: referenceDate,
            paymentMethod: .cash,
            sharedListID: listID,
            payer: alice,
            split: .payerOnly)
        let correction = ExpenseCorrected(
            correctsEventID: added.id,
            payer: bob,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate.addingTimeInterval(60))
        let expenses = ExpenseProjection.expenses(from: [.expenseAdded(added), .expenseCorrected(correction)])

        #expect(expenses.first?.payer == bob)
        #expect(expenses.first?.split == .equally(among: [alice, bob]))
    }

    @Test("Sin payer/split en la corrección, se conservan los originales")
    func sinPayerSplitEnLaCorreccionSeConservanLosOriginales() {
        let alice = ParticipantID()
        let listID = SharedListID()
        let added = ExpenseAdded(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            category: "hogar",
            date: referenceDate,
            paymentMethod: .cash,
            sharedListID: listID,
            payer: alice,
            split: .payerOnly)
        let correction = ExpenseCorrected(
            correctsEventID: added.id,
            concept: "renta agosto",
            recordedAt: referenceDate.addingTimeInterval(60))
        let expenses = ExpenseProjection.expenses(from: [.expenseAdded(added), .expenseCorrected(correction)])

        #expect(expenses.first?.concept == "renta agosto")
        #expect(expenses.first?.payer == alice)
        #expect(expenses.first?.split == .payerOnly)
    }

    @Test("clearsSharedContext vuelve el gasto personal, conservándolo (ADR-0027)")
    func clearsSharedContextVuelveElGastoPersonal() {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let added = ExpenseAdded(
            amount: Money(amount: 100, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            date: referenceDate,
            paymentMethod: .cash,
            sharedListID: SharedListID(),
            payer: alice,
            split: .equally(among: [alice, bob]))
        let correction = ExpenseCorrected(
            correctsEventID: added.id,
            clearsSharedContext: true,
            recordedAt: referenceDate.addingTimeInterval(60))
        let expenses = ExpenseProjection.expenses(from: [.expenseAdded(added), .expenseCorrected(correction)])

        // Sigue existiendo — quitar de la lista no es borrar.
        #expect(expenses.count == 1)
        #expect(expenses.first?.concept == "gasolina")
        #expect(expenses.first?.amount.amount == 100)
        #expect(expenses.first?.sharedListID == nil)
        #expect(expenses.first?.payer == nil)
        #expect(expenses.first?.split == nil)
    }

    @Test("Una corrección puede mover un gasto personal a una lista compartida (ADR-0027)")
    func correccionPuedeMoverUnGastoPersonalAUnaLista() {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let listID = SharedListID()
        let added = ExpenseAdded(
            amount: Money(amount: 100, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            date: referenceDate,
            paymentMethod: .cash)
        let correction = ExpenseCorrected(
            correctsEventID: added.id,
            sharedListID: listID,
            payer: alice,
            split: .equally(among: [alice, bob]),
            recordedAt: referenceDate.addingTimeInterval(60))
        let expenses = ExpenseProjection.expenses(from: [.expenseAdded(added), .expenseCorrected(correction)])

        #expect(expenses.first?.sharedListID == listID)
        #expect(expenses.first?.payer == alice)
    }

    @Test("Sin clearsSharedContext, una corrección normal conserva la lista compartida")
    func sinClearsSharedContextSeConservaLaLista() {
        let listID = SharedListID()
        let alice = ParticipantID()
        let added = ExpenseAdded(
            amount: Money(amount: 100, currency: .mxn),
            concept: "renta",
            category: "hogar",
            date: referenceDate,
            paymentMethod: .cash,
            sharedListID: listID,
            payer: alice,
            split: .payerOnly)
        let correction = ExpenseCorrected(
            correctsEventID: added.id,
            concept: "renta agosto",
            recordedAt: referenceDate.addingTimeInterval(60))
        let expenses = ExpenseProjection.expenses(from: [.expenseAdded(added), .expenseCorrected(correction)])

        #expect(expenses.first?.concept == "renta agosto")
        #expect(expenses.first?.sharedListID == listID)
        #expect(expenses.first?.payer == alice)
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

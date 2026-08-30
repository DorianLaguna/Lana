import Foundation
import Testing
@testable import LanaCore

@Suite("Expense.personalAmount")
struct PersonalAmountTests {
    private func sharedExpense(payer: ParticipantID, split: SplitRule, amount: Decimal = 1000) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: "renta",
            date: .now,
            sharedListID: SharedListID(),
            payer: payer,
            split: split)
    }

    @Test("Sin sharedListID, regresa el monto completo")
    func sinSharedListIDRegresaElMontoCompleto() {
        let expense = Expense(kind: .expense, amount: Money(amount: 500, currency: .mxn), concept: "café", date: .now)
        #expect(expense.personalAmount(viewerIdentities: [:]) == expense.amount)
    }

    @Test("Compartido pero sin identidad marcada todavía, regresa el monto completo")
    func sinIdentidadMarcadaRegresaElMontoCompleto() {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let expense = sharedExpense(payer: alice, split: .equally(among: [alice, bob]))
        #expect(expense.personalAmount(viewerIdentities: [:]) == expense.amount)
    }

    @Test("Partes iguales entre 2: mi parte es la mitad, sin importar quién pagó")
    func partesIgualesMiParteEsLaMitad() throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let expense = sharedExpense(payer: alice, split: .equally(among: [alice, bob]), amount: 1000)
        let listID = try #require(expense.sharedListID)

        #expect(expense.personalAmount(viewerIdentities: [listID: bob]) == Money(amount: 500, currency: .mxn))
    }

    @Test(".payerOnly y yo pagué: mi parte es el monto completo")
    func payerOnlyYYoPagueMiParteEsElMontoCompleto() throws {
        let alice = ParticipantID()
        let expense = sharedExpense(payer: alice, split: .payerOnly)
        let listID = try #require(expense.sharedListID)

        #expect(expense.personalAmount(viewerIdentities: [listID: alice]) == expense.amount)
    }

    @Test(".payerOnly y pagó alguien más: mi parte es cero, no el monto completo")
    func payerOnlyYPagoAlguienMasMiParteEsCero() throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let expense = sharedExpense(payer: alice, split: .payerOnly)
        let listID = try #require(expense.sharedListID)

        #expect(expense.personalAmount(viewerIdentities: [listID: bob]) == Money.zero(.mxn))
    }

    /// El split se congela en el evento (ADR-0007) y no se recalcula hacia
    /// atrás, así que quien se une después no aparece en los gastos viejos.
    /// Eso no es "no se pudo resolver" — es que de verdad no participó.
    @Test("Si no salgo en el split congelado, mi parte es cero, no el gasto entero")
    func fueraDelSplitCongeladoMiParteEsCero() throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let carla = ParticipantID()
        let expense = sharedExpense(payer: alice, split: .equally(among: [alice, bob]))
        let listID = try #require(expense.sharedListID)

        #expect(expense.personalAmount(viewerIdentities: [listID: carla]) == Money.zero(.mxn))
    }
}

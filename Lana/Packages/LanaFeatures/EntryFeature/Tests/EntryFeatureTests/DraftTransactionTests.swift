import Foundation
import LanaCore
import Testing
@testable import EntryFeature

@Suite("DraftTransaction")
struct DraftTransactionTests {
    @Test("Un ingreso nunca guarda categoría, aunque el borrador tenga una")
    func unIngresoNuncaGuardaCategoria() {
        var draft = DraftTransaction(amount: 15000, concept: "Sueldo", category: "otro")
        draft.kind = .income

        #expect(draft.asExpense().category == nil)
    }

    @Test("Un gasto sí guarda la categoría elegida")
    func unGastoSiGuardaLaCategoria() {
        let draft = DraftTransaction(amount: 131, concept: "Dulces", category: "despensa")

        #expect(draft.asExpense().category == "despensa")
    }

    @Test("La subcategoría que propone el parser llega tal cual al borrador, y se puede editar")
    func laSubcategoriaDelParserLlegaAlBorradorYSePuedeEditar() {
        let result = ParseResult(
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            subcategory: "dulces")
        var draft = DraftTransaction(result: result, fallbackDate: .now)

        #expect(draft.subcategory == "dulces")

        draft.subcategory = "chocolates"

        #expect(draft.asExpense().subcategory == "chocolates")
    }

    @Test("Lo dictado sale como dictado, y lo que vuelve a revisión conserva su origen (ADR-0049)")
    func elOrigenViajaConElBorrador() {
        let dictated = DraftTransaction(
            result: ParseResult(amount: Money(amount: 50, currency: .mxn), concept: "tacos"),
            fallbackDate: .now)
        #expect(dictated.asExpense().source == .dictation)

        let fromApplePay = Expense(
            kind: .expense,
            amount: Money(amount: 89, currency: .mxn),
            concept: "OXXO",
            date: .now,
            needsReview: true,
            source: .applePay)
        #expect(DraftTransaction(expense: fromApplePay).asExpense().source == .applePay)
    }
}

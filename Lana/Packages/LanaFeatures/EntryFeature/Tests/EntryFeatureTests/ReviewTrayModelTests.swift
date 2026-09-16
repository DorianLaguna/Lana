import Foundation
import LanaCore
import Testing
@testable import EntryFeature

@Suite("Bandeja por revisar")
@MainActor
struct ReviewTrayModelTests {
    private func expense(
        concept: String = "OXXO Reforma",
        needsReview: Bool = true,
        recurringItemID: RecurringItemID? = nil) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: 120, currency: .mxn),
            concept: concept,
            category: "despensa",
            date: Date(),
            paymentMethod: .cash,
            needsReview: needsReview,
            recurringItemID: recurringItemID)
    }

    @Test("Confirmar quita la marca de revisión del mismo movimiento, sin crear otro")
    func confirmarCorrigeElMismoMovimiento() async throws {
        let original = expense()
        let store = InMemoryExpenseStore(seed: [original])
        let model = ReviewTrayModel(expenses: [original], store: store)

        let saved = await model.confirm()

        #expect(saved)
        let stored = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(stored.count == 1)
        #expect(stored.first?.id == original.id)
        #expect(stored.first?.needsReview == false)
    }

    @Test("Confirmar conserva de qué recurrente salió el movimiento (ADR-0042)")
    func confirmarConservaElRecurrente() async throws {
        let recurringID = RecurringItemID()
        let original = expense(concept: "Renta", recurringItemID: recurringID)
        let store = InMemoryExpenseStore(seed: [original])
        let model = ReviewTrayModel(expenses: [original], store: store)

        _ = await model.confirm()

        let stored = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(stored.first?.recurringItemID == recurringID)
    }

    @Test("Lo editado en la bandeja es lo que se guarda")
    func seGuardaLoEditado() async throws {
        let original = expense()
        let store = InMemoryExpenseStore(seed: [original])
        let model = ReviewTrayModel(expenses: [original], store: store)
        model.drafts[0].concept = "Súper"
        model.drafts[0].amount = 320

        _ = await model.confirm()

        let stored = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(stored.first?.concept == "Súper")
        #expect(stored.first?.amount.amount == 320)
    }

    @Test("Quitar de la bandeja no toca el movimiento guardado")
    func quitarNoBorra() async throws {
        let original = expense()
        let store = InMemoryExpenseStore(seed: [original])
        let model = ReviewTrayModel(expenses: [original], store: store)

        model.remove(id: original.id)
        _ = await model.confirm()

        let stored = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(model.drafts.isEmpty)
        #expect(stored.first?.needsReview == true)
    }

    @Test("El botón dice cuántos se confirman")
    func etiquetaDelBoton() {
        let store = InMemoryExpenseStore()
        let uno = ReviewTrayModel(expenses: [expense()], store: store)
        let tres = ReviewTrayModel(expenses: [expense(), expense(), expense()], store: store)

        #expect(uno.confirmLabel == "Confirmar")
        #expect(tres.confirmLabel == "Confirmar los 3")
    }
}

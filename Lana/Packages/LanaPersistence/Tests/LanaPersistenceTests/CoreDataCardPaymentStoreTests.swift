import Foundation
import LanaCore
import Testing
@testable import LanaPersistence

/// `CoreDataExpenseStore`'s `CardPaymentStore` conformance — extiende el
/// mismo tipo que `CoreDataExpenseStoreTests` (mismo `@Suite(.serialized)`,
/// definido ahí) por la misma razón que el resto de los archivos de esta
/// carpeta: `.serialized` solo serializa dentro de una suite, y cada test
/// aquí crea su propio `NSPersistentContainer`.
extension CoreDataExpenseStoreTests {
    @Test("Registrar un pago hace round-trip completo")
    func registrarUnPagoHaceRoundTrip() async throws {
        let store = try await makeStore()
        let cardID = CardID()
        let payment = CardPaymentRecorded(cardID: cardID, amount: Money(amount: 1500, currency: .mxn), date: .now)

        try await store.recordPayment(payment)
        let events = try await store.events()

        let recorded = events.compactMap { event -> CardPaymentRecorded? in
            guard case let .cardPaymentRecorded(payment) = event else { return nil }
            return payment
        }
        #expect(recorded.count == 1)
        #expect(recorded.first?.cardID == cardID)
        #expect(recorded.first?.amount.amount == 1500)
    }

    @Test("events() incluye tanto cargos como pagos, sin filtrar por rango")
    func eventsIncluyeCargosYPagos() async throws {
        let store = try await makeStore()
        let cardID = CardID()
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 300, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            date: .now,
            paymentMethod: .credit(cardID: cardID)))
        try await store.recordPayment(CardPaymentRecorded(
            cardID: cardID,
            amount: Money(amount: 300, currency: .mxn),
            date: .now))

        let events = try await store.events()
        let kinds = Set(events.map { event -> String in
            switch event {
            case .expenseAdded: "expenseAdded"
            case .incomeAdded: "incomeAdded"
            case .expenseCorrected: "expenseCorrected"
            case .expenseVoided: "expenseVoided"
            case .settlementRecorded: "settlementRecorded"
            case .cardPaymentRecorded: "cardPaymentRecorded"
            }
        })
        #expect(kinds.contains("expenseAdded"))
        #expect(kinds.contains("cardPaymentRecorded"))
    }
}

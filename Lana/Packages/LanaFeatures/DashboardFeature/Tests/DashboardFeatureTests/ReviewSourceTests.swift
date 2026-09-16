import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("Por revisar — de dónde vino (ADR-0049)")
@MainActor
struct ReviewSourceTests {
    @Test("Cuenta solo lo pendiente que llegó por Apple Pay")
    func cuentaSoloLoDeApplePay() async {
        let now = Date()
        func movement(_ source: CaptureSource?, needsReview: Bool) -> Expense {
            Expense(
                kind: .expense,
                amount: Money(amount: 100, currency: .mxn),
                concept: "algo",
                date: now,
                needsReview: needsReview,
                source: source)
        }
        let model = DashboardModel(
            store: InMemoryExpenseStore(seed: [
                movement(.applePay, needsReview: true),
                movement(.applePay, needsReview: true),
                movement(.applePay, needsReview: false),
                movement(.dictation, needsReview: true),
                movement(nil, needsReview: true)
            ]),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore(),
            referenceDate: now)
        await model.onAppear()

        #expect(model.needsReviewItems.count == 4)
        #expect(model.needsReviewFromApplePayCount == 2)
    }
}

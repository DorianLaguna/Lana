import LanaCore
import LanaParsing
import LanaPersistence
import LanaSpeech
import Observation

/// El único lugar donde se decide qué implementación concreta se usa
/// (Docs/ARCHITECTURE.md → Composición). Las features nunca ven esto —
/// solo los protocolos de `LanaCore`.
@MainActor
@Observable
final class AppDependencies {
    let parser: any ExpenseParsing
    let store: any ExpenseStore
    let cardStore: any CardStore
    let cardPaymentStore: any CardPaymentStore
    let vocabularyStore: any CorrectionVocabularyStore
    let recurringItemStore: any RecurringItemStore
    let sharedListStore: any SharedListStore
    let speech: any SpeechTranscribing
    let purchases: any PurchaseGating

    private init(
        parser: any ExpenseParsing,
        store: any ExpenseStore,
        cardStore: any CardStore,
        cardPaymentStore: any CardPaymentStore,
        vocabularyStore: any CorrectionVocabularyStore,
        recurringItemStore: any RecurringItemStore,
        sharedListStore: any SharedListStore,
        speech: any SpeechTranscribing,
        purchases: any PurchaseGating) {
        self.parser = parser
        self.store = store
        self.cardStore = cardStore
        self.cardPaymentStore = cardPaymentStore
        self.vocabularyStore = vocabularyStore
        self.recurringItemStore = recurringItemStore
        self.sharedListStore = sharedListStore
        self.speech = speech
        self.purchases = purchases
    }

    /// Las implementaciones reales. `Lana.entitlements` todavía no tiene un
    /// contenedor de iCloud provisionado (`icloud-container-identifiers`
    /// vacío) — hasta que exista, el store cae a local
    /// (Docs/.claude/skills/cloudkit-sharing: "la app cae a modo local...
    /// No revientes."). `purchases` es un stand-in: `LanaPurchases`
    /// (StoreKit 2 real) todavía no existe, es Fase 10.
    ///
    /// `CoreDataExpenseStore` conforma a `ExpenseStore`, `CardStore` y
    /// `CorrectionVocabularyStore` a la vez — mismo contenedor, sin repetir
    /// el crash de containers concurrentes documentado en
    /// `LanaManagedObjectModel.swift` (ADR-0014).
    static func live() async throws -> AppDependencies {
        let store = try await CoreDataExpenseStore(cloudKitContainerIdentifier: nil)
        return AppDependencies(
            // `cardStore`/`expenseStore` en vivo, no snapshots — antes se
            // leían una sola vez aquí y se congelaban en el parser por el
            // resto de la sesión; una tarjeta agregada después nunca
            // entraba a su vocabulario hasta reiniciar la app. Ver el doc
            // comment de `FoundationModelsExpenseParsing`.
            parser: FoundationModelsExpenseParsing(vocabularyStore: store, cardStore: store, expenseStore: store),
            store: store,
            cardStore: store,
            cardPaymentStore: store,
            vocabularyStore: store,
            recurringItemStore: store,
            sharedListStore: store,
            speech: AppleSpeechTranscribing(),
            purchases: InMemoryPurchaseGating(isUnlocked: true))
    }

    /// Implementaciones falsas, para `#Preview`.
    static func preview() -> AppDependencies {
        AppDependencies(
            parser: InMemoryExpenseParsing(),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            cardPaymentStore: InMemoryCardPaymentStore(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            recurringItemStore: InMemoryRecurringItemStore(),
            sharedListStore: InMemorySharedListStore(),
            speech: InMemorySpeechTranscribing(),
            purchases: InMemoryPurchaseGating(isUnlocked: true))
    }
}

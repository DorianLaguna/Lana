import CardsFeature
import Foundation
import LanaCore
import LanaInsights
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
    let syncStatus: any SyncStatusReporting
    /// Etiqueta tipos de gasto como Necesidad/Deseo/Ahorro para el análisis.
    /// Nunca ve montos: el código suma (`BudgetMix`, ADR-0037).
    let classifier: any SpendingClassifying
    /// Redacta el análisis a partir de cifras ya calculadas, y propone una
    /// regla de presupuesto del catálogo cerrado.
    let narrator: any InsightNarrating
    /// Contesta preguntas en lenguaje natural llamando a cálculos
    /// deterministas (`LedgerToolbox`). El modelo nunca ve el historial crudo.
    let querying: any InsightQuerying
    /// Mismo objeto que `store`/`cardStore`/`sharedListStore` en `.live()`,
    /// `nil` en `.preview()` — lo único que lo necesita es
    /// `AppDelegate.attach(store:)`, para aceptar invitaciones de `CKShare`
    /// (ADR-0020). Ninguna feature debe leer esta propiedad.
    let concreteExpenseStore: CoreDataExpenseStore?

    private init(
        parser: any ExpenseParsing,
        store: any ExpenseStore,
        cardStore: any CardStore,
        cardPaymentStore: any CardPaymentStore,
        vocabularyStore: any CorrectionVocabularyStore,
        recurringItemStore: any RecurringItemStore,
        sharedListStore: any SharedListStore,
        speech: any SpeechTranscribing,
        purchases: any PurchaseGating,
        syncStatus: any SyncStatusReporting,
        classifier: any SpendingClassifying,
        narrator: any InsightNarrating,
        querying: any InsightQuerying,
        concreteExpenseStore: CoreDataExpenseStore?) {
        self.parser = parser
        self.store = store
        self.cardStore = cardStore
        self.cardPaymentStore = cardPaymentStore
        self.vocabularyStore = vocabularyStore
        self.recurringItemStore = recurringItemStore
        self.sharedListStore = sharedListStore
        self.speech = speech
        self.purchases = purchases
        self.syncStatus = syncStatus
        self.classifier = classifier
        self.narrator = narrator
        self.querying = querying
        self.concreteExpenseStore = concreteExpenseStore
    }

    /// La carga en curso o terminada de `live()`, compartida por todo el
    /// proceso. Se guarda la `Task` y no la instancia para que dos llamadas
    /// que lleguen mientras la primera aún carga esperen a la misma.
    private static var sharedLoad: Task<AppDependencies, Error>?

    /// Las dependencias reales, creadas una sola vez por proceso. Es lo que
    /// usan la app y `AddTransactionIntent`, que corren en el mismo proceso:
    /// si cada uno llamara `live()`, el intent abriría un segundo
    /// `NSPersistentCloudKitContainer` sobre el mismo `.sqlite` mientras la app
    /// sigue viva en segundo plano, y el guardado fallaba solo en ese caso
    /// (ADR-0041). Si la carga falla, no se cachea: la siguiente llamada
    /// reintenta.
    static func shared() async throws -> AppDependencies {
        if let sharedLoad {
            return try await sharedLoad.value
        }
        let load = Task { try await live() }
        sharedLoad = load
        do {
            return try await load.value
        } catch {
            if sharedLoad == load {
                sharedLoad = nil
            }
            throw error
        }
    }

    /// Las implementaciones reales. Fuera de `shared()`, no se llama: una
    /// segunda instancia en el mismo proceso abre un segundo contenedor sobre
    /// el mismo store (ADR-0041). `Lana.entitlements` ya tiene un
    /// contenedor de iCloud provisionado (ADR-0020) — con una cuenta de
    /// iCloud activa en el dispositivo, `CoreDataExpenseStore.live` sincroniza
    /// de verdad; sin ella, cae a local sin romper nada
    /// (Docs/.claude/skills/cloudkit-sharing: "la app cae a modo local...
    /// No revientes."). `purchases` es un stand-in: `LanaPurchases`
    /// (StoreKit 2 real) todavía no existe, es Fase 10.
    ///
    /// `CoreDataExpenseStore` conforma a `ExpenseStore`, `CardStore` y
    /// `CorrectionVocabularyStore` a la vez — mismo contenedor, sin repetir
    /// el crash de containers concurrentes documentado en
    /// `LanaManagedObjectModel.swift` (ADR-0014).
    static func live() async throws -> AppDependencies {
        let store = try await CoreDataExpenseStore.live(cloudKitContainerIdentifier: "iCloud.com.dorianlaguna.Lana")
        return AppDependencies(
            // `cardStore`/`expenseStore` en vivo, no snapshots — antes se
            // leían una sola vez aquí y se congelaban en el parser por el
            // resto de la sesión; una tarjeta agregada después nunca
            // entraba a su vocabulario hasta reiniciar la app. Ver el doc
            // comment de `FoundationModelsExpenseParsing`.
            parser: FoundationModelsExpenseParsing(
                vocabularyStore: store,
                cardStore: store,
                expenseStore: store,
                sharedListStore: store),
            store: store,
            cardStore: store,
            cardPaymentStore: store,
            vocabularyStore: store,
            recurringItemStore: store,
            sharedListStore: store,
            speech: AppleSpeechTranscribing(),
            purchases: InMemoryPurchaseGating(isUnlocked: true),
            syncStatus: CloudSyncMonitor(containerIdentifier: "iCloud.com.dorianlaguna.Lana"),
            classifier: FoundationModelsSpendingClassifying(),
            narrator: FoundationModelsInsightNarrating(),
            querying: FoundationModelsInsightQuerying(
                store: store,
                sharedListStore: store,
                cardStore: store,
                cardPaymentStore: store,
                recurringItemStore: store),
            concreteExpenseStore: store)
    }

    /// Un `CardsModel` armado con estos stores. Lo usa `ContentView` para
    /// presentar la superficie de Tarjetas como hoja cuando la guía de Apple Pay
    /// pide "Ajustes → Tarjetas" durante el onboarding (R3.4) — antes de que
    /// exista la pestaña de Tarjetas de `MainTabView`. `MainTabView` arma el suyo
    /// aparte porque además lo conserva como `@State` para refrescos.
    func makeCardsModel() -> CardsModel {
        CardsModel(cardStore: cardStore, store: store, cardPaymentStore: cardPaymentStore)
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
            purchases: InMemoryPurchaseGating(isUnlocked: true),
            syncStatus: InMemorySyncStatusReporting(.synced(lastSuccess: .now)),
            classifier: InMemorySpendingClassifying(),
            narrator: InMemoryInsightNarrating(),
            querying: InMemoryInsightQuerying(),
            concreteExpenseStore: nil)
    }
}

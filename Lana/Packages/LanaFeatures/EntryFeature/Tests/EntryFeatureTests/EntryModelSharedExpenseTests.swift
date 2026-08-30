import Foundation
import LanaCore
import Testing
@testable import EntryFeature

/// Cómo `EntryModel.submit()` resuelve `payerHint`/`splitHint` contra las
/// listas compartidas reales del usuario — suite aparte de `EntryModelTests`
/// por tamaño, no por tema (ADR-0025).
@Suite("EntryModel — detección de gasto compartido")
@MainActor
struct EntryModelSharedExpenseTests {
    let alice = Participant(displayName: "Alice")
    let bob = Participant(displayName: "Bob")

    @Test("payerHint que calza con un solo participante manda el gasto a esa lista, con needsReview forzado")
    func payerHintQueCalzaMandaElGastoALaLista() async {
        let depa = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .equally(among: [
            alice.id, bob.id
        ]))
        let sharedListStore = InMemorySharedListStore(seed: [depa])
        let result = ParseResult(
            amount: Money(amount: 200, currency: .mxn),
            concept: "renta",
            category: "hogar",
            isShared: true,
            payerHint: "Alice",
            splitHint: "igual",
            needsReview: false)
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: sharedListStore)
        await model.onAppear()
        model.inputText = "renta 200, la dividí con Alice"
        await model.submit()

        let draft = model.drafts.first
        #expect(draft?.sharedListID == depa.id)
        #expect(draft?.payer == alice.id)
        #expect(draft?.split == .equally(among: [alice.id, bob.id]))
        #expect(draft?.needsReview == true)
    }

    @Test("payerHint ambiguo (mismo nombre en 2 listas) se queda personal, pero marca needsReview")
    func payerHintAmbiguoSeQuedaPersonalConNeedsReview() async {
        let depa = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .payerOnly)
        let viaje = SharedList(
            name: "Viaje",
            participants: [alice, Participant(displayName: "Carol")],
            defaultSplit: .payerOnly)
        let sharedListStore = InMemorySharedListStore(seed: [depa, viaje])
        let result = ParseResult(
            amount: Money(amount: 150, currency: .mxn),
            concept: "cena",
            category: "comida",
            isShared: true,
            payerHint: "Alice",
            needsReview: false)
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: sharedListStore)
        await model.onAppear()
        model.inputText = "cena 150 con Alice"
        await model.submit()

        let draft = model.drafts.first
        #expect(draft?.sharedListID == nil)
        #expect(draft?.payer == nil)
        #expect(draft?.needsReview == true)
    }

    @Test("Sin payerHint, un gasto normal no se marca needsReview solo por tener listas compartidas")
    func sinPayerHintNoSeTocaNeedsReview() async {
        let depa = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .payerOnly)
        let sharedListStore = InMemorySharedListStore(seed: [depa])
        let result = ParseResult(
            amount: Money(amount: 90, currency: .mxn),
            concept: "café",
            category: "comida",
            needsReview: false)
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: sharedListStore)
        await model.onAppear()
        model.inputText = "café 90"
        await model.submit()

        let draft = model.drafts.first
        #expect(draft?.sharedListID == nil)
        #expect(draft?.needsReview == false)
    }

    @Test("Sin isShared, un payerHint 'yo' NO manda el gasto a la lista — el bug reportado (ADR-0027)")
    func sinIsSharedUnPayerHintYoNoCompartte() async {
        // El caso exacto que rompió en producción: el modelo llenaba
        // `payerHint: "yo"` en casi cualquier "pagué X", y con una sola lista
        // con identidad marcada, `bestMatch` la resolvía sin ambigüedad —
        // todos los gastos personales acababan en la lista compartida.
        let depa = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .payerOnly)
        let sharedListStore = InMemorySharedListStore(seed: [depa])
        try? await sharedListStore.setViewerParticipantID(bob.id, for: depa.id)
        let result = ParseResult(
            amount: Money(amount: 300, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            isShared: false,
            payerHint: "yo",
            needsReview: false)
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: sharedListStore)
        await model.onAppear()
        model.inputText = "pagué 300 de gasolina"
        await model.submit()

        let draft = model.drafts.first
        #expect(draft?.sharedListID == nil)
        #expect(draft?.payer == nil)
        #expect(draft?.needsReview == false)
    }

    @Test("'yo' como payerHint resuelve contra la identidad marcada en esa lista")
    func yoResuelveContraLaIdentidadMarcadaEnEsaLista() async {
        let depa = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .payerOnly)
        let sharedListStore = InMemorySharedListStore(seed: [depa])
        try? await sharedListStore.setViewerParticipantID(bob.id, for: depa.id)
        let result = ParseResult(
            amount: Money(amount: 60, currency: .mxn),
            concept: "internet",
            category: "hogar",
            isShared: true,
            payerHint: "yo",
            splitHint: "yo",
            needsReview: false)
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: sharedListStore)
        await model.onAppear()
        model.inputText = "internet 60, lo pagué yo"
        await model.submit()

        let draft = model.drafts.first
        #expect(draft?.sharedListID == depa.id)
        #expect(draft?.payer == bob.id)
        #expect(draft?.split == .payerOnly)
    }
}

import Foundation
import LanaCore
import Testing
@testable import EntryFeature

/// Aprendizaje de categoría al confirmar (ADR-0012), carga de subcategorías y
/// el arranque automático del widget (ADR-0018). Suite aparte de
/// `EntryModelTests` por tamaño, no por tema — ese archivo pasaba el límite
/// de `type_body_length`.
@Suite("EntryModel — vocabulario y arranque")
@MainActor
struct EntryModelVocabularyAndStartupTests {
    @Test("Corregir la categoría de un borrador la registra como aprendizaje al confirmar")
    func corregirCategoriaLaRegistraAlConfirmar() async {
        let result = ParseResult(amount: Money(amount: 90, currency: .mxn), concept: "bocina", category: "comida")
        let vocabularyStore = InMemoryCorrectionVocabularyStore()
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: vocabularyStore,
            sharedListStore: InMemorySharedListStore())
        await model.onAppear()
        model.inputText = "bocina 90 pesos"
        await model.submit()

        model.drafts[0].category = "ocio"
        await model.confirm()

        let entries = await vocabularyStore.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.term == "bocina")
        #expect(entries.first?.category == "ocio")
    }

    @Test("No corregir la categoría no registra nada")
    func noCorregirNoRegistraNada() async {
        let result = ParseResult(amount: Money(amount: 90, currency: .mxn), concept: "café", category: "comida")
        let vocabularyStore = InMemoryCorrectionVocabularyStore()
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: vocabularyStore,
            sharedListStore: InMemorySharedListStore())
        await model.onAppear()
        model.inputText = "café 90 pesos"
        await model.submit()
        await model.confirm()

        let entries = await vocabularyStore.allEntries()
        #expect(entries.isEmpty)
    }

    @Test("onAppear carga las subcategorías ya usadas, agrupadas y deduplicadas por categoría")
    func onAppearCargaSubcategoriasPorCategoria() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense, amount: Money(amount: 50, currency: .mxn), concept: "chicles",
            category: "despensa", subcategory: "dulces", date: .now))
        try await store.save(Expense(
            kind: .expense, amount: Money(amount: 60, currency: .mxn), concept: "chicles otra vez",
            category: "despensa", subcategory: "dulces", date: .now))
        try await store.save(Expense(
            kind: .expense, amount: Money(amount: 300, currency: .mxn), concept: "gasolina",
            category: "transporte", subcategory: "gasolina", date: .now))
        let model = EntryModel(
            parser: InMemoryExpenseParsing(),
            store: store,
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())

        await model.onAppear()

        #expect(model.allSubcategories["despensa"] == ["dulces"])
        #expect(model.allSubcategories["transporte"] == ["gasolina"])
    }
}

@Suite("EntryModel — atajo del widget (ADR-0018)")
@MainActor
struct EntryModelAutoStartListeningTests {
    @Test("onAppear(startListening: true) arranca a escuchar solo")
    func onAppearStartListeningArrancaAEscucharSolo() async {
        let result = ParseResult(amount: Money(amount: 300, currency: .mxn), concept: "súper", category: "despensa")
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(fixedTranscript: "gasté 300 en el súper"),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())

        await model.onAppear(startListening: true)

        #expect(model.stage == .reviewing)
        #expect(model.inputText == "gasté 300 en el súper")
    }

    @Test("onAppear sin availability no intenta escuchar, aunque se pida startListening")
    func onAppearSinAvailabilityNoIntentaEscuchar() async {
        let model = EntryModel(
            parser: InMemoryExpenseParsing(availability: .notEnabled),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())

        await model.onAppear(startListening: true)

        #expect(model.stage == .unavailable(.notEnabled))
    }
}

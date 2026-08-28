import Foundation
import LanaCore
import Testing
@testable import EntryFeature

@Suite("EntryModel")
@MainActor
struct EntryModelTests {
    @Test("onAppear con el modelo disponible pasa a componer")
    func onAppearDisponiblePasaAComponer() async {
        let model = EntryModel(
            parser: InMemoryExpenseParsing(),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        #expect(model.stage == .composing)
    }

    @Test("onAppear sin disponibilidad muestra el onboarding correcto", arguments: [
        ParsingAvailability.deviceNotEligible,
        .notEnabled,
        .modelNotReady,
        .unknown
    ])
    func onAppearSinDisponibilidadMuestraOnboarding(availability: ParsingAvailability) async {
        let model = EntryModel(
            parser: InMemoryExpenseParsing(availability: availability),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        #expect(model.stage == .unavailable(availability))
    }

    @Test("Enviar texto vacío no hace nada")
    func enviarTextoVacioNoHaceNada() async {
        let model = EntryModel(
            parser: InMemoryExpenseParsing(),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "   "
        await model.submit()
        #expect(model.stage == .composing)
        #expect(model.drafts.isEmpty)
    }

    @Test("Enviar texto parseable pasa a revisar con el borrador cargado")
    func enviarTextoParseablePasaARevisar() async {
        let result = ParseResult(
            amount: Money(amount: 131, currency: .mxn),
            concept: "dulces",
            category: "despensa",
            needsReview: false)
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "dulces 131 pesos"
        await model.submit()

        #expect(model.stage == .reviewing)
        #expect(model.drafts.count == 1)
        #expect(model.drafts.first?.amount == 131)
        #expect(model.drafts.first?.concept == "dulces")
    }

    @Test("Una frase con varios gastos carga varios borradores")
    func fraseConVariosGastosCargaVariosBorradores() async {
        let results = [
            ParseResult(amount: Money(amount: 131, currency: .mxn), concept: "dulces", category: "despensa"),
            ParseResult(amount: Money(amount: 1010, currency: .mxn), concept: "gasolina", category: "transporte")
        ]
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: results),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "dulces 131 y gasolina 1010"
        await model.submit()

        #expect(model.drafts.count == 2)
    }

    @Test("Confirmar guarda todos los borradores, incluso los que necesitan revisión")
    func confirmarGuardaTodosLosBorradoresAunConNeedsReview() async throws {
        let result = ParseResult(
            amount: Money(amount: 45, currency: .mxn),
            concept: "estacionamiento",
            category: "transporte",
            needsReview: true)
        let store = InMemoryExpenseStore()
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: store,
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "45 de estacionamiento"
        await model.submit()
        await model.confirm()

        #expect(model.stage == .saved)
        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.count == 1)
        #expect(saved.first?.needsReview == true)
    }

    @Test("Editar un borrador antes de confirmar guarda la edición, no el original")
    func editarBorradorAntesDeConfirmarGuardaLaEdicion() async throws {
        let result = ParseResult(amount: Money(amount: 100, currency: .mxn), concept: "algo", category: "otro")
        let store = InMemoryExpenseStore()
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: store,
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "100 de algo"
        await model.submit()

        model.drafts[0].amount = 120
        model.drafts[0].concept = "algo corregido"
        await model.confirm()

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.first?.amount.amount == 120)
        #expect(saved.first?.concept == "algo corregido")
    }

    @Test("startOver limpia todo y regresa a componer")
    func startOverLimpiaTodo() async {
        let result = ParseResult(amount: Money(amount: 100, currency: .mxn), concept: "algo", category: "otro")
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "100 de algo"
        await model.submit()

        model.startOver()

        #expect(model.stage == .composing)
        #expect(model.inputText.isEmpty)
        #expect(model.drafts.isEmpty)
    }

    @Test("Escuchar transcribe y sigue directo a revisar, sin un camino de parseo aparte")
    func escucharTranscribeYSigueARevisar() async {
        let result = ParseResult(amount: Money(amount: 300, currency: .mxn), concept: "súper", category: "despensa")
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(fixedTranscript: "gasté 300 en el súper"),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        await model.startListening()

        #expect(model.stage == .reviewing)
        #expect(model.inputText == "gasté 300 en el súper")
        #expect(model.drafts.first?.concept == "súper")
    }

    @Test("Sin permiso de voz, escuchar no avanza y deja ver por qué")
    func sinPermisoDeVozNoAvanza() async {
        let model = EntryModel(
            parser: InMemoryExpenseParsing(),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(
                availability: .permissionNotDetermined,
                permissionResult: .permissionDenied),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        await model.startListening()

        #expect(model.stage == .composing)
        #expect(model.speechAvailability == .permissionDenied)
    }

    @Test("Corregir la categoría de un borrador la registra como aprendizaje al confirmar")
    func corregirCategoriaLaRegistraAlConfirmar() async {
        let result = ParseResult(amount: Money(amount: 90, currency: .mxn), concept: "bocina", category: "comida")
        let vocabularyStore = InMemoryCorrectionVocabularyStore()
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: vocabularyStore)
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
            vocabularyStore: vocabularyStore)
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
            vocabularyStore: InMemoryCorrectionVocabularyStore())

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
            vocabularyStore: InMemoryCorrectionVocabularyStore())

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
            vocabularyStore: InMemoryCorrectionVocabularyStore())

        await model.onAppear(startListening: true)

        #expect(model.stage == .unavailable(.notEnabled))
    }
}

import Foundation
import LanaCore
import Testing
@testable import EntryFeature

/// Cómo `EntryModel.submit()` resuelve `paymentMethodHint`/`cardAliasHint`
/// contra las tarjetas reales del usuario — suite aparte de `EntryModelTests`
/// por tamaño, no por tema.
@Suite("EntryModel — resolución de método de pago")
@MainActor
struct EntryModelPaymentMethodTests {
    @Test("Un hint de crédito con alias que coincide con una tarjeta real se resuelve a esa tarjeta")
    func hintDeCreditoConAliasQueCoincideSeResuelve() async throws {
        let cardStore = InMemoryCardStore()
        let card = try Card(
            alias: "Nu",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await cardStore.save(card)

        let result = ParseResult(
            amount: Money(amount: 300, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            paymentMethodHint: .credit,
            cardAliasHint: "la Nu")
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: cardStore,
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "gasolina 300 con la Nu"
        await model.submit()

        #expect(model.drafts.first?.paymentMethod == .credit(cardID: card.id))
    }

    @Test("Mencionar el alias de una tarjeta la resuelve aunque no se diga 'crédito' — el bug reportado")
    func mencionarElAliasResuelveLaTarjetaSinDecirCredito() async throws {
        let cardStore = InMemoryCardStore()
        let card = try Card(
            alias: "Banamex",
            lastFourDigits: "9911",
            limit: Money(amount: 20000, currency: .mxn),
            cutoffDay: 10,
            dueDay: 2,
            kind: .debit)
        try await cardStore.save(card)

        // El modelo no siempre extrae "crédito"/"débito" cuando la frase
        // solo nombra la tarjeta — `paymentMethodHint` viene `nil` a
        // propósito en este test.
        let result = ParseResult(
            amount: Money(amount: 300, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            cardAliasHint: "la tarjeta Banamex")
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: cardStore,
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "300 gasolina con la tarjeta Banamex"
        await model.submit()

        #expect(model.drafts.first?.paymentMethod == .debit(cardID: card.id))
    }

    @Test("El tipo de la tarjeta lo decide la tarjeta, no lo que se dijo al capturar")
    func elTipoLoDecideLaTarjetaNoLoDichoAlCapturar() async throws {
        let cardStore = InMemoryCardStore()
        let card = try Card(
            alias: "Nu",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5,
            kind: .debit)
        try await cardStore.save(card)

        // Dice "crédito" pero la tarjeta Nu está configurada como débito —
        // la tarjeta gana.
        let result = ParseResult(
            amount: Money(amount: 300, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            paymentMethodHint: .credit,
            cardAliasHint: "la Nu")
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: cardStore,
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "gasolina 300 con crédito de la Nu"
        await model.submit()

        #expect(model.drafts.first?.paymentMethod == .debit(cardID: card.id))
    }

    @Test("Un hint de crédito sin tarjeta que coincida cae a efectivo, no inventa una tarjeta")
    func hintDeCreditoSinCoincidenciaCaeAEfectivo() async {
        let result = ParseResult(
            amount: Money(amount: 300, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            paymentMethodHint: .credit,
            cardAliasHint: "la azul")
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "gasolina 300 con la azul"
        await model.submit()

        #expect(model.drafts.first?.paymentMethod == .cash)
    }

    @Test("Un hint de efectivo se resuelve directo, sin tocar tarjetas")
    func hintDeEfectivoSeResuelveDirecto() async {
        let result = ParseResult(
            amount: Money(amount: 85, currency: .mxn),
            concept: "café",
            category: "comida",
            paymentMethodHint: .cash)
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "café 85 en efectivo"
        await model.submit()

        #expect(model.drafts.first?.paymentMethod == .cash)
    }

    @Test("Sin ninguna mención de cómo se pagó, el default es efectivo")
    func sinMencionDefaultEsEfectivo() async {
        let result = ParseResult(amount: Money(amount: 85, currency: .mxn), concept: "café", category: "comida")
        let model = EntryModel(
            parser: InMemoryExpenseParsing(results: [result]),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        await model.onAppear()
        model.inputText = "café 85"
        await model.submit()

        #expect(model.drafts.first?.paymentMethod == .cash)
    }
}

import Foundation
import LanaCore
import Testing
@testable import EntryFeature

@Suite("EntryModel — seguir dictando y lo recién guardado")
@MainActor
struct EntryModelResumeTests {
    private static let superResult = ParseResult(
        amount: Money(amount: 300, currency: .mxn),
        concept: "súper",
        category: "despensa")

    private static let uberResult = ParseResult(
        amount: Money(amount: 120, currency: .mxn),
        concept: "uber",
        category: "transporte")

    private func makeModel(
        speech: any SpeechTranscribing,
        results: [ParseResult] = [],
        store: InMemoryExpenseStore = InMemoryExpenseStore()) -> EntryModel {
        EntryModel(
            parser: InMemoryExpenseParsing(results: results),
            store: store,
            cardStore: InMemoryCardStore(),
            speech: speech,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())
    }

    @Test("Seguir dictando suma movimientos a los ya revisados, no los reemplaza")
    func seguirDictandoConserva() async {
        let speech = ControllableSpeechTranscribing()
        let model = makeModel(speech: speech, results: [Self.uberResult])
        model.drafts = [DraftTransaction(result: Self.superResult, fallbackDate: Date())]

        let listening = Task { await model.resumeListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("120 en uber", finalizedText: "")
        while model.inputText.isEmpty {
            await Task.yield()
        }
        await speech.stopTranscribing()
        _ = await listening.value

        #expect(model.drafts.map(\.concept) == ["súper", "uber"])
    }

    @Test("Seguir dictando sin decir nada deja intacto lo que ya estaba en revisión")
    func seguirDictandoSinDictarNada() async {
        let speech = ControllableSpeechTranscribing()
        let model = makeModel(speech: speech)
        model.drafts = [DraftTransaction(result: Self.superResult, fallbackDate: Date())]

        let listening = Task { await model.resumeListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.stopTranscribing()
        _ = await listening.value

        #expect(model.drafts.map(\.concept) == ["súper"])
        #expect(model.stage == .reviewing)
    }

    @Test("Al guardar, el modelo dice qué movimientos se acaban de crear")
    func loRecienGuardado() async {
        let model = makeModel(speech: InMemorySpeechTranscribing(), results: [Self.superResult])
        model.inputText = "gasté 300 en el súper"
        await model.submit()
        let ids = model.drafts.map(\.id)

        await model.confirm()

        #expect(model.stage == .saved)
        #expect(model.lastSavedIDs == ids)
    }
}

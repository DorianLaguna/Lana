import Foundation
import LanaCore
import Testing
@testable import EntryFeature

@Suite("EntryModel — preview en vivo mientras se dicta")
@MainActor
struct EntryModelLivePreviewTests {
    private static let superResult = ParseResult(
        amount: Money(amount: 300, currency: .mxn),
        concept: "súper",
        category: "despensa")

    private func makeModel(speech: any SpeechTranscribing, parser: any ExpenseParsing) -> EntryModel {
        EntryModel(
            parser: parser,
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: speech,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())
    }

    @Test("Lo ya finalizado se parsea sin dejar de escuchar")
    func loFinalizadoSeParseaSinDejarDeEscuchar() async {
        let speech = ControllableSpeechTranscribing()
        let model = makeModel(speech: speech, parser: CountingExpenseParsing(results: [Self.superResult]))

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("gasté 300 en el súper", finalizedText: "gasté 300 en el súper")
        while model.liveDrafts.isEmpty {
            await Task.yield()
        }

        #expect(model.stage == .listening)
        #expect(model.liveDrafts.map(\.concept) == ["súper"])

        await model.cancel()
        _ = await listening.value
    }

    @Test("Lo volátil no se parsea en vivo — solo al terminar")
    func loVolatilNoSeParseaEnVivo() async {
        let speech = ControllableSpeechTranscribing()
        let parser = CountingExpenseParsing(results: [Self.superResult])
        let model = makeModel(speech: speech, parser: parser)

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("gasté 300")
        while model.inputText.isEmpty {
            await Task.yield()
        }
        #expect(await parser.parsedTexts.isEmpty)

        await speech.stopTranscribing()
        _ = await listening.value

        #expect(await parser.parsedTexts == ["gasté 300"])
        #expect(model.stage == .reviewing)
    }

    @Test("Al terminar de dictar, reusa el preview sin parsear otra vez")
    func alTerminarReusaElPreviewSinParsearOtraVez() async {
        let speech = ControllableSpeechTranscribing()
        let parser = CountingExpenseParsing(results: [Self.superResult])
        let model = makeModel(speech: speech, parser: parser)

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("gasté 300 en el súper", finalizedText: "gasté 300 en el súper")
        while model.liveDrafts.isEmpty {
            await Task.yield()
        }

        await speech.stopTranscribing()
        _ = await listening.value

        #expect(model.stage == .reviewing)
        #expect(model.drafts.map(\.concept) == ["súper"])
        #expect(model.liveDrafts.isEmpty)
        #expect(await parser.parsedTexts == ["gasté 300 en el súper"])
    }

    @Test("Si se dijo algo más después del preview, se parsea la frase completa")
    func siSeDijoAlgoMasSeParseaLaFraseCompleta() async {
        let speech = ControllableSpeechTranscribing()
        let parser = CountingExpenseParsing(results: [Self.superResult])
        let model = makeModel(speech: speech, parser: parser)

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("gasté 300 en el súper", finalizedText: "gasté 300 en el súper")
        while model.liveDrafts.isEmpty {
            await Task.yield()
        }
        await speech.yield("gasté 300 en el súper con la Nu", finalizedText: "gasté 300 en el súper")
        while model.inputText != "gasté 300 en el súper con la Nu" {
            await Task.yield()
        }

        await speech.stopTranscribing()
        _ = await listening.value

        #expect(model.stage == .reviewing)
        #expect(await parser.parsedTexts.last == "gasté 300 en el súper con la Nu")
    }

    @Test("Borrar lo dictado también borra el preview")
    func borrarLoDictadoTambienBorraElPreview() async {
        let speech = ControllableSpeechTranscribing()
        let model = makeModel(speech: speech, parser: CountingExpenseParsing(results: [Self.superResult]))

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("gasté 300 en el súper", finalizedText: "gasté 300 en el súper")
        while model.liveDrafts.isEmpty {
            await Task.yield()
        }

        let clearing = Task { await model.clearTranscript() }
        while !model.liveDrafts.isEmpty {
            await Task.yield()
        }
        #expect(model.stage == .listening)

        await model.cancel()
        _ = await listening.value
        _ = await clearing.value
    }
}

/// Registra cada texto que se le pide parsear — la única forma de probar
/// que el preview en vivo se reusa en vez de parsear dos veces lo mismo.
private actor CountingExpenseParsing: ExpenseParsing {
    let availability: ParsingAvailability = .available
    private let results: [ParseResult]
    private(set) var parsedTexts: [String] = []

    init(results: [ParseResult]) {
        self.results = results
    }

    nonisolated func prewarm() {}

    func parse(_ text: String) async throws -> [ParseResult] {
        parsedTexts.append(text)
        return results
    }
}

import Foundation
import LanaCore
import Testing
@testable import EntryFeature

@Suite("EntryModel — nivel del micrófono y transcripción finalizada")
@MainActor
struct EntryModelAudioLevelTests {
    private func makeModel(speech: any SpeechTranscribing) -> EntryModel {
        EntryModel(
            parser: InMemoryExpenseParsing(),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: speech,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())
    }

    @Test("La onda recibe el nivel real del micrófono mientras se escucha y vuelve a cero al terminar")
    func nivelDelMicrofono() async {
        let speech = ControllableSpeechTranscribing()
        let model = makeModel(speech: speech)

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.sendLevel(0.6)
        while model.audioLevel != 0.6 {
            await Task.yield()
        }
        #expect(model.audioLevel == 0.6)

        await speech.stopTranscribing()
        _ = await listening.value

        #expect(model.audioLevel == 0)
    }

    @Test("La transcripción distingue lo ya finalizado de la palabra en curso")
    func transcripcionFinalizada() async {
        let speech = ControllableSpeechTranscribing()
        let model = makeModel(speech: speech)

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("300 de súper y 120 en ub", finalizedText: "300 de súper")
        while model.inputText.isEmpty {
            await Task.yield()
        }

        #expect(model.finalizedTranscript == "300 de súper")
        #expect(model.inputText == "300 de súper y 120 en ub")

        await model.cancel()
        _ = await listening.value
    }
}

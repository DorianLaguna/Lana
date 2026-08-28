import Foundation
import LanaCore
import Testing
@testable import EntryFeature

@Suite("EntryModel — clearTranscript()")
@MainActor
struct EntryModelClearTranscriptTests {
    @Test("Sin estar escuchando, no hace nada")
    func sinEstarEscuchandoNoHaceNada() async {
        let model = EntryModel(
            parser: InMemoryExpenseParsing(),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: InMemorySpeechTranscribing(),
            vocabularyStore: InMemoryCorrectionVocabularyStore())
        model.inputText = "algo"

        await model.clearTranscript()

        #expect(model.inputText == "algo")
    }

    @Test("Mientras escucha, borra lo dictado y sigue escuchando — pedido explícito del usuario")
    func mientrasEscuchaBorraLoDictadoYSigueEscuchando() async {
        let speech = ControllableSpeechTranscribing()
        let model = EntryModel(
            parser: InMemoryExpenseParsing(),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: speech,
            vocabularyStore: InMemoryCorrectionVocabularyStore())

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("gasté trescientos")
        while model.inputText.isEmpty {
            await Task.yield()
        }
        #expect(model.inputText == "gasté trescientos")

        // `clearTranscript()` no regresa hasta que la sesión NUEVA que
        // arranca también termine — igual que `startListening()`, es una
        // llamada que vive mientras se sigue escuchando. Se corre en su
        // propia tarea, igual que ya se hace con el botón real del mic.
        let clearing = Task { await model.clearTranscript() }
        while !model.inputText.isEmpty {
            await Task.yield()
        }

        // Sigue en `.listening`, no en `.composing`, y el transcript volvió
        // a estar vacío hasta que se diga algo de nuevo.
        #expect(model.stage == .listening)
        #expect(model.inputText.isEmpty)

        await speech.stopTranscribing()
        _ = await listening.value
        _ = await clearing.value
    }
}

/// A diferencia de `InMemorySpeechTranscribing` (que emite un transcript
/// fijo y termina de inmediato), este doble deja el stream abierto hasta
/// que algo llame `stopTranscribing()` — igual que la sesión de escucha
/// real, necesario para probar `clearTranscript()` a la mitad de "seguir
/// escuchando".
private actor ControllableSpeechTranscribing: SpeechTranscribing {
    let availability: SpeechAvailability = .available
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    func requestPermission() async -> SpeechAvailability {
        .available
    }

    nonisolated func transcribe() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.store(continuation) }
        }
    }

    private func store(_ continuation: AsyncThrowingStream<String, Error>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ snapshot: String) async {
        continuation?.yield(snapshot)
    }

    func stopTranscribing() async {
        continuation?.finish()
        continuation = nil
    }
}

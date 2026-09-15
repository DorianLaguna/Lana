import Testing
@testable import LanaCore

@Suite("InMemorySpeechTranscribing")
struct SpeechTranscribingTests {
    @Test("Está disponible y ya tiene permiso, sin pedir nada")
    func disponibleSinPedirPermiso() async {
        let speech = InMemorySpeechTranscribing()
        #expect(await speech.availability == .available)
        #expect(await speech.requestPermission() == .available)
    }

    @Test("Emite el transcript fijo y termina")
    func emiteTranscriptFijo() async throws {
        let speech = InMemorySpeechTranscribing(fixedTranscript: "gasté 100 en café")
        var received: [TranscriptSnapshot] = []
        for try await snapshot in speech.transcribe() {
            received.append(snapshot)
        }
        #expect(received == [TranscriptSnapshot(text: "gasté 100 en café", finalizedText: "gasté 100 en café")])
    }
}

import LanaCore
import Testing
@testable import LanaSpeech

@Suite("AnalyzerTranscript")
struct AnalyzerTranscriptTests {
    @Test("Un resultado volátil se muestra pero no cuenta como finalizado")
    func volatilSeMuestraPeroNoSeFinaliza() {
        var transcript = AnalyzerTranscript()

        let snapshot = transcript.apply(text: "gasté trescientos", isFinal: false)

        #expect(snapshot == TranscriptSnapshot(text: "gasté trescientos", finalizedText: ""))
    }

    @Test("Un volátil nuevo reemplaza al anterior en vez de sumarse")
    func volatilNuevoReemplazaAlAnterior() {
        var transcript = AnalyzerTranscript()
        _ = transcript.apply(text: "gasté 348 hi", isFinal: false)

        let snapshot = transcript.apply(text: "gasté 348 en despensa", isFinal: false)

        #expect(snapshot.text == "gasté 348 en despensa")
    }

    @Test("Los tramos finales se concatenan y el volátil va detrás")
    func finalesSeConcatenanYElVolatilVaDetras() {
        var transcript = AnalyzerTranscript()
        _ = transcript.apply(text: "gasté 300 en el súper", isFinal: true)
        _ = transcript.apply(text: " y 150 de gasolina", isFinal: true)

        let snapshot = transcript.apply(text: "con la Nu", isFinal: false)

        #expect(snapshot == TranscriptSnapshot(
            text: "gasté 300 en el súper y 150 de gasolina con la Nu",
            finalizedText: "gasté 300 en el súper y 150 de gasolina"))
    }

    @Test("Un final descarta el volátil que lo precedía — son el mismo tramo")
    func finalDescartaElVolatilPrevio() {
        var transcript = AnalyzerTranscript()
        _ = transcript.apply(text: "gasté tres", isFinal: false)

        let snapshot = transcript.apply(text: "gasté 300", isFinal: true)

        #expect(snapshot == TranscriptSnapshot(text: "gasté 300", finalizedText: "gasté 300"))
    }

    @Test("reset() empieza de cero")
    func resetEmpiezaDeCero() {
        var transcript = AnalyzerTranscript()
        _ = transcript.apply(text: "gasté 300", isFinal: true)
        transcript.reset()

        let snapshot = transcript.apply(text: "Uber", isFinal: false)

        #expect(snapshot == TranscriptSnapshot(text: "Uber", finalizedText: ""))
    }
}

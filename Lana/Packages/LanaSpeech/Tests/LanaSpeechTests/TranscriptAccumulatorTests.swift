import Testing
@testable import LanaSpeech

@Suite("TranscriptAccumulator")
struct TranscriptAccumulatorTests {
    @Test("Un snapshot creciente dentro del mismo segmento pasa igual")
    func unSnapshotCrecienteDentroDelMismoSegmentoPasaIgual() {
        var accumulator = TranscriptAccumulator()
        #expect(accumulator.combine(rawSnapshot: "gasté", isFinal: false) == "gasté")
        #expect(accumulator.combine(rawSnapshot: "gasté trescientos", isFinal: false) == "gasté trescientos")
    }

    @Test("Un segmento finalizado y luego un snapshot más corto se antepone — el bug reportado")
    func unSegmentoFinalizadoSeAntepone() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "gasté trescientos pesos", isFinal: true)
        // El reconocedor arranca un segmento nuevo desde cero tras la
        // pausa — sin acumular, esto se vería como que "se reinició".
        let result = accumulator.combine(rawSnapshot: "en el súper", isFinal: false)
        #expect(result == "gasté trescientos pesos en el súper")
    }

    @Test("Varios segmentos finalizados se concatenan en orden")
    func variosSegmentosFinalizadosSeConcatenanEnOrden() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "gasté trescientos", isFinal: true)
        _ = accumulator.combine(rawSnapshot: "en el súper", isFinal: true)
        let result = accumulator.combine(rawSnapshot: "ayer", isFinal: false)
        #expect(result == "gasté trescientos en el súper ayer")
    }

    @Test("reset() olvida todo lo acumulado")
    func resetOlvidaTodoLoAcumulado() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "gasté trescientos", isFinal: true)
        accumulator.reset()
        let result = accumulator.combine(rawSnapshot: "hola", isFinal: false)
        #expect(result == "hola")
    }
}

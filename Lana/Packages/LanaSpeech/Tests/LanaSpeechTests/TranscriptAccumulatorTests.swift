import Testing
@testable import LanaSpeech

@Suite("TranscriptAccumulator")
struct TranscriptAccumulatorTests {
    @Test("Un snapshot creciente dentro del mismo segmento pasa igual")
    func unSnapshotCrecienteDentroDelMismoSegmentoPasaIgual() {
        var accumulator = TranscriptAccumulator()
        #expect(accumulator.combine(rawSnapshot: "gasté", segmentAnchor: 0, isFinal: false) == "gasté")
        #expect(
            accumulator.combine(rawSnapshot: "gasté trescientos", segmentAnchor: 0, isFinal: false)
                == "gasté trescientos")
    }

    @Test("Un segmento finalizado y luego un snapshot más corto se antepone — el bug reportado")
    func unSegmentoFinalizadoSeAntepone() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "gasté trescientos pesos", segmentAnchor: 0, isFinal: true)
        // El reconocedor arranca un segmento nuevo desde cero tras la
        // pausa — sin acumular, esto se vería como que "se reinició".
        let result = accumulator.combine(rawSnapshot: "en el súper", segmentAnchor: 2.1, isFinal: false)
        #expect(result == "gasté trescientos pesos en el súper")
    }

    @Test("Varios segmentos finalizados se concatenan en orden")
    func variosSegmentosFinalizadosSeConcatenanEnOrden() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "gasté trescientos", segmentAnchor: 0, isFinal: true)
        _ = accumulator.combine(rawSnapshot: "en el súper", segmentAnchor: 1.4, isFinal: true)
        let result = accumulator.combine(rawSnapshot: "ayer", segmentAnchor: 2.8, isFinal: false)
        #expect(result == "gasté trescientos en el súper ayer")
    }

    @Test("Una pausa reinicia el segmento sin marcarlo isFinal — el bug reportado por el usuario")
    func unaPausaReiniciaElSegmentoSinMarcarloFinal() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "50 pesos de gomitas", segmentAnchor: 0, isFinal: false)
        // El usuario se queda pensando; al retomar, el reconocedor arranca
        // un segmento nuevo — el audio avanzó, así que el anchor cambia,
        // aunque isFinal se quede en false igual que antes de la pausa.
        let afterReset = accumulator.combine(rawSnapshot: "con", segmentAnchor: 3.6, isFinal: false)
        #expect(afterReset == "50 pesos de gomitas con")
        let result = accumulator.combine(rawSnapshot: "con tarjeta bancomer", segmentAnchor: 3.6, isFinal: false)
        #expect(result == "50 pesos de gomitas con tarjeta bancomer")
    }

    @Test("Una revisión del mismo tramo de audio no se antepone — el bug de '170 173' reportado")
    func unaRevisionDelMismoTramoDeAudioNoSeAntepone() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "170", segmentAnchor: 0, isFinal: false)
        // El reconocedor corrige el número ya dicho sin avanzar en el
        // audio — mismo anchor, así que no debe anteponerse.
        let revised = accumulator.combine(rawSnapshot: "173", segmentAnchor: 0, isFinal: false)
        #expect(revised == "173")
        let grown = accumulator.combine(rawSnapshot: "173 pesos", segmentAnchor: 0, isFinal: false)
        #expect(grown == "173 pesos")
        let result = accumulator.combine(rawSnapshot: "173 pesos mango enchilado", segmentAnchor: 0, isFinal: false)
        #expect(result == "173 pesos mango enchilado")
    }

    @Test("Una autocorrección que descarta una mala lectura no se antepone, aunque el número de palabras baje")
    func unaAutocorreccionQueDescartaUnaMalaLecturaNoSeAntepone() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "120 papas", segmentAnchor: 0, isFinal: false)
        // Segundo segmento real: el audio avanzó (anchor distinto).
        _ = accumulator.combine(rawSnapshot: "y", segmentAnchor: 1.8, isFinal: false)
        _ = accumulator.combine(rawSnapshot: "y 348", segmentAnchor: 1.8, isFinal: false)
        // El reconocedor oye mal y arma "y 348 hi" — mismo anchor, sigue
        // siendo el mismo tramo de audio, todavía sin cerrar.
        _ = accumulator.combine(rawSnapshot: "y 348 hi", segmentAnchor: 1.8, isFinal: false)
        // Se autocorrige: descarta "hi" y vuelve a "y", pero el anchor
        // sigue siendo el mismo tramo — no es un segmento nuevo, así que
        // "y 348 hi" nunca debe quedar pegado en el resultado.
        let corrected = accumulator.combine(rawSnapshot: "y", segmentAnchor: 1.8, isFinal: false)
        #expect(corrected == "120 papas y")
        let result = accumulator.combine(rawSnapshot: "y 348 despensa", segmentAnchor: 1.8, isFinal: false)
        #expect(result == "120 papas y 348 despensa")
    }

    @Test("El arranque de un segmento nuevo que repite la cola del anterior no se duplica — el bug reportado")
    func elArranqueDeUnSegmentoNuevoQueRepiteLaColaDelAnteriorNoSeDuplica() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "128", segmentAnchor: 0, isFinal: false)
        _ = accumulator.combine(rawSnapshot: "128 pesos", segmentAnchor: 0, isFinal: false)
        _ = accumulator.combine(
            rawSnapshot: "128 pesos mangos enchiladas", segmentAnchor: 0, isFinal: false)
        // El usuario se queda pensando qué más decir. El segmento nuevo
        // (anchor distinto) arranca repitiendo, palabra por palabra, lo
        // mismo que ya se dijo — el solape del buffer de audio, no algo
        // que el usuario haya vuelto a decir.
        let midReplay = accumulator.combine(rawSnapshot: "128", segmentAnchor: 3.2, isFinal: false)
        #expect(midReplay == "128 pesos mangos enchiladas")
        let fullReplay = accumulator.combine(
            rawSnapshot: "128 pesos mangos enchiladas", segmentAnchor: 3.2, isFinal: false)
        #expect(fullReplay == "128 pesos mangos enchiladas")
        // Si después sí sigue hablando, lo nuevo se agrega sin duplicar.
        let withNewWords = accumulator.combine(
            rawSnapshot: "128 pesos mangos enchiladas con tarjeta", segmentAnchor: 3.2, isFinal: false)
        #expect(withNewWords == "128 pesos mangos enchiladas con tarjeta")
    }

    @Test("reset() olvida todo lo acumulado")
    func resetOlvidaTodoLoAcumulado() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.combine(rawSnapshot: "gasté trescientos", segmentAnchor: 0, isFinal: true)
        accumulator.reset()
        let result = accumulator.combine(rawSnapshot: "hola", segmentAnchor: 0, isFinal: false)
        #expect(result == "hola")
    }
}

import LanaCore

/// Arma el `TranscriptSnapshot` a partir de los resultados de
/// `SpeechTranscriber` (ADR-0043).
///
/// `SpeechTranscriber` reporta dos clases de resultado: **volátil** (su
/// hipótesis actual del tramo que se sigue oyendo, que el siguiente
/// resultado reemplaza completo) y **final** (un tramo que ya no va a
/// cambiar, que se suma a lo anterior). Con eso basta concatenar los finales
/// y poner detrás el último volátil — ya no hay que adivinar cortes de
/// segmento por timestamps, que era todo el trabajo del
/// `TranscriptAccumulator` que usaba `SFSpeechRecognizer` (ADR-0015).
///
/// Puro y sin `import Speech` a propósito — se prueba sin mic ni simulador.
struct AnalyzerTranscript {
    private var finalized = ""
    private var volatile = ""

    /// - Parameters:
    ///   - text: el texto de un resultado de `SpeechTranscriber`.
    ///   - isFinal: si el resultado cierra su tramo de audio.
    /// - Returns: el snapshot completo hasta ahora.
    mutating func apply(text: String, isFinal: Bool) -> TranscriptSnapshot {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFinal {
            finalized = Self.join(finalized, clean)
            volatile = ""
        } else {
            volatile = clean
        }
        return TranscriptSnapshot(text: Self.join(finalized, volatile), finalizedText: finalized)
    }

    mutating func reset() {
        finalized = ""
        volatile = ""
    }

    private static func join(_ head: String, _ tail: String) -> String {
        if head.isEmpty {
            return tail
        }
        if tail.isEmpty {
            return head
        }
        return "\(head) \(tail)"
    }
}

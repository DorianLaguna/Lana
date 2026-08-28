/// `SFSpeechRecognizer` on-device finaliza su segmento de reconocimiento
/// después de una pausa y empieza uno nuevo desde cero — el snapshot que
/// entrega deja de ser acumulativo justo ahí, lo que el usuario ve como que
/// "se reinicia lo que dijo" al hablar despacio. `AppleSpeechTranscribing`
/// promete snapshots crecientes (ADR-0015); este tipo cierra esa brecha
/// concatenando los segmentos ya finalizados con el que sigue en curso.
/// Puro y sin `import Speech` a propósito — se prueba sin mic ni simulador.
struct TranscriptAccumulator {
    private var finalizedPrefix = ""

    /// - Parameters:
    ///   - rawSnapshot: lo que el reconocedor acaba de reportar para el
    ///     segmento en curso — ya no crece desde el segmento anterior si
    ///     ese se acaba de finalizar.
    ///   - isFinal: si `rawSnapshot` es el cierre de un segmento.
    /// - Returns: el transcript completo hasta ahora, con los segmentos ya
    ///   finalizados al frente.
    mutating func combine(rawSnapshot: String, isFinal: Bool) -> String {
        let combined = finalizedPrefix.isEmpty ? rawSnapshot : "\(finalizedPrefix) \(rawSnapshot)"
        if isFinal {
            finalizedPrefix = combined
        }
        return combined
    }

    mutating func reset() {
        finalizedPrefix = ""
    }
}

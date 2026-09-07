/// `SFSpeechRecognizer` on-device finaliza su segmento de reconocimiento
/// después de una pausa y empieza uno nuevo desde cero — el snapshot que
/// entrega deja de ser acumulativo justo ahí, lo que el usuario ve como que
/// "se reinicia lo que dijo" al hablar despacio. `AppleSpeechTranscribing`
/// promete snapshots crecientes (ADR-0015); este tipo cierra esa brecha
/// concatenando los segmentos ya cerrados con el que sigue en curso.
///
/// El corte de segmento **no llega marcado con `isFinal: true`** — eso solo
/// pasa al cerrar la sesión completa (`endAudio()`). Tampoco basta con
/// comparar el texto: el reconocedor también reescribe su hipótesis sobre
/// el mismo tramo de audio ya dicho — "348" corrigiéndose a sí mismo, o de
/// plano descartando una mala lectura ("y 348 hi" → "y 348 despensa") — y
/// eso se ve exactamente igual que un corte real desde el texto solo (el
/// número de palabras baja en ambos casos).
///
/// La señal confiable de un corte es otra: cada resultado trae en qué punto
/// del audio empieza su primer segmento (`segmentAnchor`, de
/// `SFTranscriptionSegment.timestamp`). Si el reconocedor sigue revisando
/// el mismo tramo, ese punto de partida no cambia — solo cambia su
/// interpretación. Si de verdad cerró un segmento y empezó a interpretar
/// audio nuevo, el punto de partida avanza.
///
/// Pero un corte real trae su propio problema: el buffer de audio del
/// segmento nuevo se solapa con la cola del que se acaba de cerrar, así
/// que sus primeros snapshots vuelven a "escuchar" lo último ya dicho antes
/// de seguir con algo nuevo (o de quedarse ahí, si no se dijo nada más) —
/// el segmento nuevo repite literalmente el texto del que acaba de cerrar.
/// Por eso, al abrir un segmento, sus snapshots se comparan contra el texto
/// del segmento recién cerrado (`previousSegmentText`) y se descarta esa
/// repetición inicial; solo lo que crece más allá de ella cuenta como
/// contenido nuevo.
///
/// Puro y sin `import Speech` a propósito — se prueba sin mic ni simulador;
/// `segmentAnchor` llega como `Double` desde `AppleSpeechTranscribing`, que
/// es quien sí conoce `SFTranscriptionSegment`.
struct TranscriptAccumulator {
    private var finalizedPrefix = ""
    private var lastRawSnapshot = ""
    private var currentSegmentAnchor: Double?
    private var previousSegmentText = ""

    /// - Parameters:
    ///   - rawSnapshot: lo que el reconocedor acaba de reportar para el
    ///     segmento en curso.
    ///   - segmentAnchor: dónde en el audio empieza el primer segmento de
    ///     `rawSnapshot` — mismo valor mientras siga siendo una revisión del
    ///     mismo tramo, distinto cuando el reconocedor de verdad avanzó a
    ///     audio nuevo.
    ///   - isFinal: si `rawSnapshot` cierra la sesión completa de escucha.
    /// - Returns: el transcript completo hasta ahora, con los segmentos ya
    ///   cerrados al frente y sin la repetición del arranque de cada uno.
    mutating func combine(rawSnapshot: String, segmentAnchor: Double, isFinal: Bool) -> String {
        if let currentSegmentAnchor, currentSegmentAnchor != segmentAnchor {
            let closedSegment = lastRawSnapshot
            finalizedPrefix = finalizedPrefix.isEmpty ? closedSegment : "\(finalizedPrefix) \(closedSegment)"
            previousSegmentText = closedSegment
        }
        currentSegmentAnchor = segmentAnchor
        lastRawSnapshot = rawSnapshot

        let newContent = Self.stripLeadingReplay(rawSnapshot, of: previousSegmentText)
        let combined: String = if newContent.isEmpty {
            finalizedPrefix
        } else {
            finalizedPrefix.isEmpty ? newContent : "\(finalizedPrefix) \(newContent)"
        }

        if isFinal {
            finalizedPrefix = combined
            currentSegmentAnchor = nil
            lastRawSnapshot = ""
            previousSegmentText = ""
        }
        return combined
    }

    mutating func reset() {
        finalizedPrefix = ""
        lastRawSnapshot = ""
        currentSegmentAnchor = nil
        previousSegmentText = ""
    }

    /// - Returns: `rawSnapshot` sin el prefijo que repite `previousSegment`
    ///   completo o a medias — vacío mientras el segmento nuevo siga sin
    ///   rebasar esa repetición, tal cual si diverge desde el principio
    ///   (no es una repetición, es contenido genuinamente distinto).
    private static func stripLeadingReplay(_ rawSnapshot: String, of previousSegment: String) -> String {
        guard !previousSegment.isEmpty else { return rawSnapshot }
        if rawSnapshot.hasPrefix(previousSegment) {
            let remainder = rawSnapshot.dropFirst(previousSegment.count).drop { $0 == " " }
            return String(remainder)
        }
        if previousSegment.hasPrefix(rawSnapshot) {
            return ""
        }
        return rawSnapshot
    }
}

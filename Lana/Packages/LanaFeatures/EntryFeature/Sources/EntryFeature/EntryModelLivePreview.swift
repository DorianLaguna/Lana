import Foundation
import LanaCore

/// El parseo mientras se dicta (ADR-0043). Aparte de `EntryModel.swift` por
/// tamaño, igual que `EntryModelResolving.swift`.
extension EntryModel {
    /// Se llama cuando el stream de voz termina por `stopListening()`.
    ///
    /// Si el parseo en vivo ya va (o ya fue) sobre exactamente lo que se
    /// dictó, se espera y se reusa: parsear otra vez lo mismo solo agregaría
    /// segundos de espera al tocar el micrófono. Si se dijo algo después de
    /// la última pausa, se parsea la frase completa con el `submit()` de
    /// siempre.
    func finishListening(generation: Int) async {
        let finalText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else {
            resetLivePreview()
            stage = .composing
            return
        }

        if latestLiveRequest == finalText, let liveParseTask {
            stage = .parsing
            await liveParseTask.value
            guard generation == listeningGeneration else { return }
        }
        if liveParsedText == finalText, !liveDrafts.isEmpty {
            drafts = liveDrafts
            resetLivePreview()
            stage = .reviewing
            return
        }
        resetLivePreview()
        await submit()
    }

    /// Parsea lo ya finalizado mientras el usuario sigue hablando, para
    /// mostrarle qué se va entendiendo. Un error aquí no se muestra: es un
    /// adelanto, y el parseo de verdad al terminar de dictar es el que
    /// reporta.
    func requestLiveParse(of finalizedText: String, generation: Int) {
        let text = finalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != latestLiveRequest else { return }
        latestLiveRequest = text
        guard liveParseTask == nil else { return }
        liveParseTask = Task { await runLiveParses(generation: generation) }
    }

    func resetLivePreview() {
        liveParseTask?.cancel()
        liveParseTask = nil
        latestLiveRequest = nil
        liveParsedText = ""
        liveDrafts = []
    }

    private func runLiveParses(generation: Int) async {
        while let text = latestLiveRequest, text != liveParsedText {
            let results = await (try? parser.parse(text)) ?? []
            // `resetLivePreview()` ya soltó esta tarea; no toca nada más.
            guard generation == listeningGeneration, liveParseTask != nil else { return }
            liveParsedText = text
            liveDrafts = makeDrafts(from: results)
        }
        liveParseTask = nil
    }
}

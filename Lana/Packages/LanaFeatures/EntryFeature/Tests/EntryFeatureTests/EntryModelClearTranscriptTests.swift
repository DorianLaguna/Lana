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
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())
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
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())

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

/// Vive en este archivo, y no en uno propio, porque necesita el mismo
/// `ControllableSpeechTranscribing` de abajo: las dos son pruebas de qué
/// pasa a la mitad de una sesión de escucha viva.
@Suite("EntryModel — cancel()")
@MainActor
struct EntryModelCancelTests {
    @Test("Cerrar la hoja a media frase corta el dictado y no deja nada parseado")
    func cerrarLaHojaAMediaFraseCortaElDictado() async {
        let speech = ControllableSpeechTranscribing()
        let model = EntryModel(
            parser: InMemoryExpenseParsing(),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: speech,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }
        await speech.yield("gasté trescientos")
        while model.inputText.isEmpty {
            await Task.yield()
        }

        await model.cancel()
        _ = await listening.value

        // Lo importante es `drafts`: si la sesión cancelada hubiera seguido
        // hasta `submit()`, el parser habría dejado un borrador de una hoja
        // que el usuario ya cerró, y reaparecería al volver a abrirla.
        #expect(model.drafts.isEmpty)
        #expect(model.inputText.isEmpty)
        #expect(model.stage == .composing)
    }
}

/// También aquí por el `ControllableSpeechTranscribing`: medir el alto de
/// la hoja mientras se dicta necesita una sesión de escucha viva.
@Suite("EntryModel — alto de la hoja")
@MainActor
struct EntryModelSheetHeightTests {
    private static let superResult = ParseResult(
        amount: Money(amount: 300, currency: .mxn),
        concept: "súper",
        category: "despensa")

    private func makeModel(speech: any SpeechTranscribing, results: [ParseResult] = []) -> EntryModel {
        EntryModel(
            parser: InMemoryExpenseParsing(results: results),
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore(),
            speech: speech,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            sharedListStore: InMemorySharedListStore())
    }

    @Test("Al abrir, la hoja se queda compacta")
    func alAbrirLaHojaSeQuedaCompacta() {
        let model = makeModel(speech: InMemorySpeechTranscribing())

        #expect(model.captureHeight == .compact)
    }

    @Test("El dictado crece por escalones: compacta, media y luego toda la pantalla")
    func dictandoLaHojaCrecePorEscalones() async {
        let speech = ControllableSpeechTranscribing()
        let model = makeModel(speech: speech)

        let listening = Task { await model.startListening() }
        while model.stage != .listening {
            await Task.yield()
        }

        // Una frase corta cabe en el alto compacto.
        await speech.yield("gasté 300 en el súper")
        while model.inputText.isEmpty {
            await Task.yield()
        }
        #expect(model.captureHeight == .compact)

        // Al pasar de dos renglones sube al escalón intermedio, sin brincar
        // todavía a pantalla completa.
        await speech.yield(
            "gasté 300 en el súper y 150 en la gasolina y otros 200 en la farmacia")
        while model.captureHeight == .compact {
            await Task.yield()
        }
        #expect(model.captureHeight == .medium)

        // Solo una frase de verdad larga pide toda la pantalla: lo que mide
        // este dictado son sus caracteres, y tiene que pasar de
        // `transcriptLengthForFullSheet` (140). La versión anterior se quedaba
        // en 133 y el `while` de abajo no podía terminar nunca.
        await speech.yield(
            """
            gasté 300 en el súper y 150 en la gasolina y otros 200 en la farmacia \
            de la esquina y luego 500 en la cena con los amigos del trabajo y otros \
            120 en el uber de regreso
            """)
        while model.captureHeight != .full {
            await Task.yield()
        }
        #expect(model.captureHeight == .full)

        await model.cancel()
        _ = await listening.value
    }

    @Test("Revisando siempre pide toda la pantalla — el método de pago es el último campo")
    func revisandoSiemprePideTodaLaPantalla() async {
        let model = makeModel(speech: InMemorySpeechTranscribing(), results: [Self.superResult])
        model.inputText = "gasté 300 en el súper"

        await model.submit()

        #expect(model.stage == .reviewing)
        #expect(model.captureHeight == .full)
    }

    @Test("Al terminar la captura, la hoja vuelve a pedir el alto compacto")
    func alTerminarLaCapturaVuelveAlAltoCompacto() async {
        let model = makeModel(speech: InMemorySpeechTranscribing(), results: [Self.superResult])
        model.inputText = "gasté 300 en el súper"
        await model.submit()
        #expect(model.captureHeight == .full)

        model.startOver()

        #expect(model.captureHeight == .compact)
    }
}

/// A diferencia de `InMemorySpeechTranscribing` (que emite un transcript
/// fijo y termina de inmediato), este doble deja el stream abierto hasta
/// que algo llame `stopTranscribing()` — igual que la sesión de escucha
/// real, necesario para probar `clearTranscript()` a la mitad de "seguir
/// escuchando". Interno, no privado: también lo usan las pruebas del
/// preview en vivo (`EntryModelLivePreviewTests`).
actor ControllableSpeechTranscribing: SpeechTranscribing {
    let availability: SpeechAvailability = .available
    private var continuation: AsyncThrowingStream<TranscriptSnapshot, Error>.Continuation?
    /// Lo dictado antes de que la continuation llegue al actor — ver `yield`.
    private var pending: [TranscriptSnapshot] = []
    /// Paradas que llegaron antes que la continuation del stream que paraban
    /// — ver `stopTranscribing()`.
    private var pendingStops = 0
    private var levelContinuation: AsyncStream<Float>.Continuation?
    /// El último nivel enviado antes de que alguien escuchara — misma ventana
    /// que `pending`.
    private var pendingLevel: Float?

    nonisolated func audioLevels() -> AsyncStream<Float> {
        AsyncStream { continuation in
            Task { await self.storeLevels(continuation) }
        }
    }

    private func storeLevels(_ continuation: AsyncStream<Float>.Continuation) {
        levelContinuation = continuation
        if let pendingLevel {
            continuation.yield(pendingLevel)
            self.pendingLevel = nil
        }
    }

    /// Simula el micrófono oyendo voz a cierto volumen.
    func sendLevel(_ level: Float) {
        guard let levelContinuation else {
            pendingLevel = level
            return
        }
        levelContinuation.yield(level)
    }

    func requestPermission() async -> SpeechAvailability {
        .available
    }

    nonisolated func transcribe() -> AsyncThrowingStream<TranscriptSnapshot, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.store(continuation) }
        }
    }

    private func store(_ continuation: AsyncThrowingStream<TranscriptSnapshot, Error>.Continuation) {
        // Ya habían parado este stream antes de que su continuation llegara
        // aquí: se cierra de inmediato, porque si no, quien lo itera espera
        // para siempre a un stream que nadie va a terminar.
        if pendingStops > 0 {
            pendingStops -= 1
            continuation.finish()
            return
        }
        self.continuation = continuation
        for snapshot in pending {
            continuation.yield(snapshot)
        }
        pending.removeAll()
    }

    /// `transcribe()` es `nonisolated`, así que guardar la continuation cuesta
    /// un salto al actor: entre que el modelo pide el stream y que la
    /// continuation queda guardada hay una ventana en la que un `yield` se
    /// perdía en silencio. El test que esperaba ese snapshot se quedaba
    /// girando para siempre en su `while ... { await Task.yield() }` — no
    /// pasaba con dos tests, pero con más pruebas corriendo en paralelo la
    /// carrera empezó a perderse. Con el buffer, ningún snapshot se pierde:
    /// se entrega en cuanto hay a quién entregárselo.
    /// - Parameters:
    ///   - text: todo lo dicho hasta ahora.
    ///   - finalizedText: el prefijo ya cerrado — vacío por default, como un
    ///     resultado todavía volátil que no dispara el parseo en vivo.
    func yield(_ text: String, finalizedText: String = "") async {
        let snapshot = TranscriptSnapshot(text: text, finalizedText: finalizedText)
        guard let continuation else {
            pending.append(snapshot)
            return
        }
        continuation.yield(snapshot)
    }

    /// La otra mitad de la ventana que documenta `yield`: parar mientras la
    /// continuation todavía va en camino al actor no puede ser un no-op.
    ///
    /// `clearTranscript()` encadena `stopTranscribing()` con un
    /// `startListening()` nuevo, así que al cancelar hay un segundo stream
    /// recién pedido cuya continuation puede no haber llegado. Si esa parada
    /// se pierde, el `await` de quien lo itera no se reanuda nunca y la suite
    /// entera se queda colgada sin que falle un solo `#expect`.
    func stopTranscribing() async {
        guard let continuation else {
            pendingStops += 1
            return
        }
        continuation.finish()
        self.continuation = nil
    }
}

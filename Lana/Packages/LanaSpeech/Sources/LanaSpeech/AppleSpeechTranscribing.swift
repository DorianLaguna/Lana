import AVFoundation
import Foundation
import LanaCore
import Speech

/// Por qué falló la transcripción en curso — nunca por reconocimiento en
/// servidor: `SpeechTranscriber` corre siempre on-device (ADR-0043).
enum SpeechTranscribingError: LocalizedError {
    case unavailable
    case audioFormat

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "El reconocimiento de voz no está disponible ahora mismo."
        case .audioFormat:
            "No se pudo preparar el micrófono para transcribir."
        }
    }
}

/// Implementación real de `SpeechTranscribing`: `SpeechAnalyzer` +
/// `SpeechTranscriber` (iOS 26) alimentados por `AVAudioEngine` (ADR-0043).
/// Reemplaza a `SFSpeechRecognizer` (ADR-0015): transcribe mejor frases
/// largas, es on-device por diseño — no hay modo servidor al que degradar —
/// y distingue lo que todavía puede cambiar de lo ya finalizado, que es lo
/// que habilita parsear mientras se dicta. Parada manual, igual que antes.
public actor AppleSpeechTranscribing: SpeechTranscribing {
    private let locale: Locale
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var audioInput: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var continuation: AsyncThrowingStream<TranscriptSnapshot, Error>.Continuation?
    private var transcript = AnalyzerTranscript()
    /// Qué llamada a `transcribe()` es dueña de la sesión actual. Sin esto,
    /// el `onTermination` de un stream viejo — que corre en una `Task`
    /// suelta, tarde — podía detener la sesión que `clearTranscript()`
    /// acababa de abrir. También invalida un arranque que sigue esperando
    /// (bajar el modelo del idioma tarda) si alguien detiene a la mitad.
    private var currentSession: UUID?
    /// El nivel del micrófono sale del hilo de audio, no de este actor.
    private let levels = AudioLevelBroadcaster()

    public init(locale: Locale = Locale(identifier: "es-MX")) {
        self.locale = locale
    }

    public var availability: SpeechAvailability {
        get async {
            guard SpeechTranscriber.isAvailable,
                  await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil
            else { return .unavailable }
            switch SFSpeechRecognizer.authorizationStatus() {
            case .notDetermined:
                return .permissionNotDetermined
            case .denied:
                return .permissionDenied
            case .restricted:
                return .restricted
            case .authorized:
                return hasMicrophonePermission() ? .available : .permissionDenied
            @unknown default:
                return .unavailable
            }
        }
    }

    /// Sigue pidiendo el permiso de reconocimiento de voz además del
    /// micrófono, como con `SFSpeechRecognizer`: quien ya usaba la voz no ve
    /// ningún diálogo nuevo. Si en el iPhone se confirma que `SpeechAnalyzer`
    /// no lo necesita, quitarlo ahorra un diálogo a quien llega nuevo
    /// (ADR-0043).
    public func requestPermission() async -> SpeechAvailability {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            return Self.map(speechStatus)
        }
        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return micGranted ? .available : .permissionDenied
    }

    public nonisolated func transcribe() -> AsyncThrowingStream<TranscriptSnapshot, Error> {
        let session = UUID()
        return AsyncThrowingStream { continuation in
            // Cerrar la hoja arrastrándola cancela la `Task` de la vista sin
            // pasar por `stopTranscribing()`; sin esto el micrófono seguía
            // grabando en segundo plano. Solo detiene SU sesión.
            continuation.onTermination = { [weak self] _ in
                Task { await self?.stop(session: session) }
            }
            Task { await self.start(session: session, continuation: continuation) }
        }
    }

    public func stopTranscribing() async {
        guard let session = currentSession else { return }
        await stop(session: session)
    }

    /// Se mide en el mismo tap que alimenta al analizador: la onda responde a
    /// la voz real sin abrir un segundo camino de audio.
    public nonisolated func audioLevels() -> AsyncStream<Float> {
        levels.stream()
    }

    private func start(
        session: UUID,
        continuation: AsyncThrowingStream<TranscriptSnapshot, Error>.Continuation) async {
        if let previous = currentSession {
            await stop(session: previous)
        }
        currentSession = session
        self.continuation = continuation
        transcript.reset()

        do {
            guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
                throw SpeechTranscribingError.unavailable
            }
            let transcriber = SpeechTranscriber(
                locale: supportedLocale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: [])

            // La primera vez en un dispositivo, el modelo del idioma no está
            // instalado: se baja aquí, sin salir del teléfono lo que se dicta.
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            guard currentSession == session else { return }

            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            else { throw SpeechTranscribingError.audioFormat }
            // `.lingering` mantiene el modelo cargado un rato: "Borrar y seguir
            // escuchando" abre una sesión nueva al instante, sin recargarlo.
            let analyzer = SpeechAnalyzer(
                modules: [transcriber],
                options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering))
            try await analyzer.prepareToAnalyze(in: analyzerFormat)
            guard currentSession == session else { return }
            self.analyzer = analyzer

            resultsTask = Task { [weak self] in
                do {
                    for try await result in transcriber.results {
                        await self?.handle(text: String(result.text.characters), isFinal: result.isFinal)
                    }
                } catch {
                    await self?.fail(session: session, error: error)
                }
            }

            let (inputSequence, audioInput) = AsyncStream.makeStream(of: AnalyzerInput.self)
            self.audioInput = audioInput
            try await analyzer.start(inputSequence: inputSequence)
            guard currentSession == session else { return }
            try Self.startAudio(
                engine: audioEngine,
                analyzerFormat: analyzerFormat,
                feeding: audioInput,
                levels: levels)
        } catch {
            await fail(session: session, error: error)
        }
    }

    /// Detiene el micrófono y le pide al analizador cerrar lo pendiente: los
    /// últimos resultados finales todavía llegan a `continuation` antes de
    /// terminar el stream — sin esa espera, la última frase dicha justo antes
    /// de tocar el micrófono se perdía.
    private func stop(session: UUID) async {
        guard currentSession == session else { return }
        currentSession = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        levels.send(0)
        audioInput?.finish()
        audioInput = nil
        if let analyzer {
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        await resultsTask?.value
        finishSession(throwing: nil)
    }

    private func fail(session: UUID, error: Error) async {
        guard currentSession == session else { return }
        currentSession = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        levels.send(0)
        audioInput?.finish()
        audioInput = nil
        await analyzer?.cancelAndFinishNow()
        resultsTask?.cancel()
        finishSession(throwing: error)
    }

    private func finishSession(throwing error: Error?) {
        analyzer = nil
        resultsTask = nil
        let continuation = continuation
        self.continuation = nil
        transcript.reset()
        if let error {
            continuation?.finish(throwing: error)
        } else {
            continuation?.finish()
        }
    }

    private func handle(text: String, isFinal: Bool) {
        guard let continuation else { return }
        continuation.yield(transcript.apply(text: text, isFinal: isFinal))
    }

    /// `nonisolated` a propósito: el bloque del tap corre en el hilo de
    /// audio, no en este actor. Armado dentro de un método aislado, Swift lo
    /// infiere aislado al actor y revienta al primer buffer.
    private nonisolated static func startAudio(
        engine: AVAudioEngine,
        analyzerFormat: AVAudioFormat,
        feeding audioInput: AsyncStream<AnalyzerInput>.Continuation,
        levels: AudioLevelBroadcaster) throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard let converter = BufferConverter(from: inputFormat, to: analyzerFormat) else {
            throw SpeechTranscribingError.audioFormat
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            levels.send(AudioLevelBroadcaster.level(of: buffer))
            guard let converted = converter.convert(buffer) else { return }
            audioInput.yield(AnalyzerInput(buffer: converted))
        }
        engine.prepare()
        try engine.start()
    }

    private func hasMicrophonePermission() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    private static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> SpeechAvailability {
        switch status {
        case .notDetermined:
            .permissionNotDetermined
        case .denied:
            .permissionDenied
        case .restricted:
            .restricted
        case .authorized:
            .available
        @unknown default:
            .unavailable
        }
    }
}

/// Reparte el nivel del micrófono desde el hilo de audio a quien lo escuche
/// (la onda de voz de la captura). Un solo oyente a la vez: abrir la captura
/// otra vez reemplaza al anterior. `@unchecked Sendable` porque todo acceso
/// pasa por el candado.
private final class AudioLevelBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: AsyncStream<Float>.Continuation?

    func stream() -> AsyncStream<Float> {
        let (stream, continuation) = AsyncStream.makeStream(of: Float.self, bufferingPolicy: .bufferingNewest(1))
        lock.withLock {
            self.continuation?.finish()
            self.continuation = continuation
        }
        return stream
    }

    func send(_ level: Float) {
        let continuation = lock.withLock { self.continuation }
        continuation?.yield(level)
    }

    /// El RMS del buffer en una escala de 0 a 1: de −50 dB (silencio de
    /// cuarto) a 0 dB. Lineal en decibeles porque así se oye la voz.
    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0 ..< count {
            sum += channel[index] * channel[index]
        }
        let rms = (sum / Float(count)).squareRoot()
        let decibels = 20 * log10(max(rms, 0.000_01))
        return min(max((decibels + 50) / 50, 0), 1)
    }
}

/// El micrófono entrega audio en su formato nativo (típicamente 48 kHz
/// estéreo) y `SpeechAnalyzer` pide el suyo (`bestAvailableAudioFormat`).
/// `@unchecked Sendable` porque solo lo toca el hilo de audio del tap, un
/// buffer a la vez.
private final class BufferConverter: @unchecked Sendable {
    private let converter: AVAudioConverter?
    private let outputFormat: AVAudioFormat

    init?(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) {
        self.outputFormat = outputFormat
        if inputFormat == outputFormat {
            converter = nil
            return
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return nil }
        // Sin priming: en un stream en vivo, el converter "se come" las
        // primeras muestras de cada buffer para prepararse.
        converter.primeMethod = .none
        self.converter = converter
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return nil }

        // El bloque de entrada corre de forma síncrona dentro de `convert`,
        // en este mismo hilo — nunca en paralelo con esta variable.
        nonisolated(unsafe) var delivered = false
        nonisolated(unsafe) let input = buffer
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if delivered {
                inputStatus.pointee = .noDataNow
                return nil
            }
            delivered = true
            inputStatus.pointee = .haveData
            return input
        }
        return status == .error ? nil : output
    }
}

import AVFoundation
import Foundation
import LanaCore
import Speech

/// Por qué falló la transcripción en curso — nunca por reconocimiento en
/// servidor: si el dispositivo no soporta on-device, `availability` ya lo
/// refleja antes de llegar aquí (ADR-0015).
enum SpeechTranscribingError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "El reconocimiento de voz no está disponible ahora mismo."
    }
}

/// Implementación real de `SpeechTranscribing`: `SFSpeechRecognizer` +
/// `AVAudioEngine`, on-device cuando el dispositivo lo soporta para el
/// locale dado. Parada manual — no hay detección de silencio (ADR-0015).
public actor AppleSpeechTranscribing: SpeechTranscribing {
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?
    private var accumulator = TranscriptAccumulator()

    public init(locale: Locale = Locale(identifier: "es-MX")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    public var availability: SpeechAvailability {
        guard let recognizer, recognizer.isAvailable else { return .unavailable }
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

    public nonisolated func transcribe() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { await self.startTranscribing(continuation: continuation) }
        }
    }

    public func stopTranscribing() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        continuation?.finish()
        continuation = nil
        recognitionRequest = nil
        recognitionTask = nil
        accumulator.reset()
    }

    private func startTranscribing(continuation: AsyncThrowingStream<String, Error>.Continuation) {
        self.continuation = continuation
        accumulator.reset()
        guard let recognizer, recognizer.isAvailable else {
            continuation.finish(throwing: SpeechTranscribingError.unavailable)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            continuation.finish(throwing: error)
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Solo se mandan tipos `Sendable` al actor — `result` es un
            // `SFSpeechRecognitionResult` (no `Sendable`) que este closure ya
            // no puede tocar una vez cruza a la `Task`. `segmentAnchor` es el
            // timestamp del primer segmento — la señal que `TranscriptAccumulator`
            // usa para distinguir una autocorrección de un corte real de
            // segmento, en vez de adivinar por el texto.
            let transcript = result?.bestTranscription.formattedString
            let segmentAnchor = result?.bestTranscription.segments.first?.timestamp ?? 0
            let isFinal = result?.isFinal ?? false
            guard let self else { return }
            Task { await self.handleResult(transcript, segmentAnchor: segmentAnchor, isFinal: isFinal, error: error) }
        }
    }

    private func handleResult(_ transcript: String?, segmentAnchor: Double, isFinal: Bool, error: Error?) async {
        if let transcript {
            let combined = accumulator.combine(rawSnapshot: transcript, segmentAnchor: segmentAnchor, isFinal: isFinal)
            continuation?.yield(combined)
        }
        if let error {
            continuation?.finish(throwing: error)
            await stopTranscribing()
        }
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

import Foundation

/// Por qué la captura por voz no está disponible ahora mismo — mismo
/// espíritu que `ParsingAvailability`, pero esto es permiso de usuario
/// (micrófono + reconocimiento de voz), no una capacidad fija del
/// dispositivo (ADR-0015).
public enum SpeechAvailability: Sendable, Equatable {
    /// Todavía no se pidió permiso.
    case permissionNotDetermined
    /// El usuario negó el permiso de micrófono o de reconocimiento de voz.
    case permissionDenied
    /// Restringido por controles parentales/MDM.
    case restricted
    /// El dispositivo no soporta reconocimiento de voz on-device para el
    /// locale actual. Nunca se degrada a reconocimiento en servidor
    /// silenciosamente (ADR-0015) — esto se lo decimos al usuario.
    case unavailable
    case available
}

/// Una foto del transcript mientras el usuario habla (ADR-0043).
///
/// `text` es todo lo que se ha oído, incluida la hipótesis que el
/// reconocedor todavía puede reescribir. `finalizedText` es solo el prefijo
/// que ya no va a cambiar — el reconocedor lo cierra tras una pausa. Esa
/// diferencia es lo que permite parsear mientras se sigue dictando sin
/// parsear cada palabra a medias.
public struct TranscriptSnapshot: Sendable, Equatable {
    /// Todo lo dicho hasta ahora; es lo que se muestra en pantalla.
    public let text: String
    /// El prefijo de `text` que el reconocedor ya no va a reescribir.
    public let finalizedText: String

    public init(text: String, finalizedText: String) {
        self.text = text
        self.finalizedText = finalizedText
    }
}

/// Convierte voz en texto, on-device, para alimentar el mismo
/// `ExpenseParsing.parse(_:)` que ya existe — la voz es otra forma de
/// producir texto, no un parser aparte (ADR-0015).
///
/// Nombre fijado por Docs/CONVENTIONS.md — sufijo `-ing`, como
/// `ExpenseParsing`.
public protocol SpeechTranscribing: Sendable {
    var availability: SpeechAvailability { get async }
    /// Pide permiso de micrófono y de reconocimiento de voz. Se llama la
    /// primera vez que el usuario toca el micrófono, no al abrir la
    /// pantalla (Docs/adr/0015).
    func requestPermission() async -> SpeechAvailability
    /// Snapshots crecientes del transcript mientras el usuario habla.
    /// Termina cuando se llama `stopTranscribing()` — no hay detección de
    /// silencio (Docs/adr/0015). El último snapshot antes de terminar trae
    /// todo el texto finalizado.
    func transcribe() -> AsyncThrowingStream<TranscriptSnapshot, Error>
    func stopTranscribing() async
    /// Qué tan fuerte llega la voz, de 0 a 1, mientras hay una sesión de
    /// escucha abierta. Solo es para la onda de la captura: no toca el texto
    /// ni el parseo.
    func audioLevels() -> AsyncStream<Float>
}

public extension SpeechTranscribing {
    /// Sin micrófono real (tests, previews) no hay nivel que reportar: la
    /// onda se queda en reposo.
    func audioLevels() -> AsyncStream<Float> {
        AsyncStream { $0.finish() }
    }
}

/// Implementación en memoria para tests y `#Preview` — emite un transcript
/// fijo, sin audio real.
public actor InMemorySpeechTranscribing: SpeechTranscribing {
    private let fixedTranscript: String
    private let permissionResult: SpeechAvailability
    public let availability: SpeechAvailability
    private var stopped = false

    public init(
        fixedTranscript: String = "gasté 300 en el súper",
        availability: SpeechAvailability = .available,
        permissionResult: SpeechAvailability = .available) {
        self.fixedTranscript = fixedTranscript
        self.availability = availability
        self.permissionResult = permissionResult
    }

    public func requestPermission() async -> SpeechAvailability {
        permissionResult
    }

    public nonisolated func transcribe() -> AsyncThrowingStream<TranscriptSnapshot, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(TranscriptSnapshot(text: fixedTranscript, finalizedText: fixedTranscript))
            continuation.finish()
        }
    }

    public func stopTranscribing() async {
        stopped = true
    }
}

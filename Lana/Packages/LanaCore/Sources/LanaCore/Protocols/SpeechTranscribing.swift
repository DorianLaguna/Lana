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
    /// silencio (Docs/adr/0015).
    func transcribe() -> AsyncThrowingStream<String, Error>
    func stopTranscribing() async
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

    public nonisolated func transcribe() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(fixedTranscript)
            continuation.finish()
        }
    }

    public func stopTranscribing() async {
        stopped = true
    }
}

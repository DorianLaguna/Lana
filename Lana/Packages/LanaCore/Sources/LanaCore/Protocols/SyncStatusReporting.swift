import Foundation

/// Estado real de la sincronización con iCloud — no solo si hay cuenta
/// activa. Un indicador que solo mirara `CloudKitAvailability.hasActiveAccount`
/// podría decir "sincronizado" aunque el último intento haya fallado en
/// silencio; ese indicador miente y es peor que no tenerlo (mismo espíritu
/// que ADR-0008: "un disponible en el que el usuario no confía no se
/// consulta"), ADR-0020.
public enum SyncStatus: Sendable, Equatable {
    /// Sin cuenta de iCloud activa en el dispositivo — los datos solo viven
    /// localmente. No es un error, es el modo local de siempre.
    case disabled
    case syncing
    case synced(lastSuccess: Date)
    /// `lastKnownGood` es `nil` si nunca hubo un sync exitoso todavía.
    case failed(lastKnownGood: Date?)
}

/// Reporta el estado real de sincronización con CloudKit, derivado de los
/// eventos que `NSPersistentCloudKitContainer` sí reporta — nunca inferido
/// solo de si hay cuenta de iCloud (ADR-0020).
///
/// Nombre fijado por Docs/CONVENTIONS.md — sufijo `-ing`, como
/// `ExpenseParsing`/`SpeechTranscribing`.
public protocol SyncStatusReporting: Sendable {
    var currentStatus: SyncStatus { get async }
    /// Snapshots crecientes cada vez que el sync real reporta un evento
    /// nuevo. Termina solo si quien lo implementa deja de observar — en la
    /// práctica, vive tanto como la app.
    func statusUpdates() -> AsyncStream<SyncStatus>
}

/// Implementación en memoria para tests y `#Preview` — un estado fijo, sin
/// observar nada real.
public struct InMemorySyncStatusReporting: SyncStatusReporting {
    public let currentStatus: SyncStatus

    public init(_ status: SyncStatus = .disabled) {
        currentStatus = status
    }

    public func statusUpdates() -> AsyncStream<SyncStatus> {
        let status = currentStatus
        return AsyncStream { continuation in
            continuation.yield(status)
            continuation.finish()
        }
    }
}

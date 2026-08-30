import Foundation

public enum PersistenceError: LocalizedError, Sendable {
    case noStoreDescription
    /// El coordinator no tiene ningún `NSPersistentStore` cargado — no
    /// debería pasar nunca en producción (siempre hay exactamente uno), pero
    /// compartir/aceptar un `CKShare` (ADR-0020) lo necesita explícito.
    case noPersistentStore
    /// CloudKit rechazó crear/actualizar el `CKShare` por límite de cuota
    /// (ADR-0023-adjacent). En el entorno de Desarrollo este límite es un
    /// tope temporal muy bajo a propósito (para no gastar cuota real en
    /// pruebas) — no significa que la cuenta de iCloud del usuario esté
    /// llena. Compartir una lista con mucho historial mueve todos sus
    /// eventos de golpe a la zona nueva, lo que puede rebasar ese tope.
    case cloudKitQuotaExceeded(retryAfterSeconds: TimeInterval?)
    /// Cualquier otro error de CloudKit al preparar/persistir el share —
    /// nunca se le muestra al usuario el `CKError` crudo (es un bloque de
    /// texto ilegible con UUIDs de registros), solo este mensaje genérico.
    case cloudKitSharingFailed

    public var errorDescription: String? {
        switch self {
        case .noStoreDescription:
            "El contenedor de Core Data no tiene ninguna store description."
        case .noPersistentStore:
            "El contenedor de Core Data no tiene ningún store cargado."
        case let .cloudKitQuotaExceeded(retryAfterSeconds):
            Self.quotaExceededMessage(retryAfterSeconds: retryAfterSeconds)
        case .cloudKitSharingFailed:
            "No se pudo preparar la invitación. Intenta de nuevo más tarde."
        }
    }

    private static func quotaExceededMessage(retryAfterSeconds: TimeInterval?) -> String {
        guard let retryAfterSeconds, retryAfterSeconds > 0 else {
            return """
            Se alcanzó un límite temporal de sincronización con iCloud — no significa que tu \
            cuenta esté llena. Intenta de nuevo en unos minutos.
            """
        }
        let minutes = max(1, Int(retryAfterSeconds / 60))
        return """
        Se alcanzó un límite temporal de sincronización con iCloud — no significa que tu \
        cuenta esté llena. Intenta de nuevo en \(minutes) minuto\(minutes == 1 ? "" : "s").
        """
    }
}

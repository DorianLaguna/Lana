import CloudKit
import Foundation

/// Si hay una cuenta de iCloud activa **con acceso real al contenedor de
/// CloudKit de esta app**. `LanaPersistence` lo usa para decidir si
/// `CoreDataExpenseStore` sincroniza con CloudKit o cae a almacenamiento
/// puramente local — sin esto, `NSPersistentCloudKitContainer` sigue
/// funcionando en disco, pero nunca sincroniza (Docs/.claude/skills/cloudkit-sharing:
/// "Si el usuario no tiene sesión, la app cae a modo local... No revientes.").
///
/// Antes esto miraba `FileManager.ubiquityIdentityToken` — la señal correcta
/// para apps que usan iCloud Drive/Documents (un contenedor "ubiquity"), no
/// para apps que, como esta, solo declaran `CloudKit` en
/// `com.apple.developer.icloud-services` (`Lana.entitlements`) sin ningún
/// `com.apple.developer.ubiquity-container-identifiers`. En la práctica esa
/// señal resultó intermitente en dispositivo real — a veces `nil` con una
/// cuenta de iCloud activa de verdad, mostrando "necesitas una cuenta de
/// iCloud activa" de forma incorrecta (reportado por el usuario). El chequeo
/// correcto para CloudKit puro es `CKContainer.accountStatus()`, que refleja
/// el estado real de la cuenta para *este* contenedor específico, sin
/// depender de ninguna capability de Documents/ubiquity.
public enum CloudKitAvailability {
    /// `true` si `CKContainer(identifier:).accountStatus()` reporta
    /// `.available` para el contenedor dado. `false` en cualquier otro caso
    /// (`.noAccount`, `.restricted`, `.temporarilyUnavailable`,
    /// `.couldNotDetermine`, o si la llamada falla) — mismo criterio
    /// conservador que antes: ante la duda, cae a local en vez de intentar
    /// sincronizar.
    public static func hasActiveAccount(containerIdentifier: String) async -> Bool {
        let container = CKContainer(identifier: containerIdentifier)
        guard let status = try? await container.accountStatus() else { return false }
        return status == .available
    }
}

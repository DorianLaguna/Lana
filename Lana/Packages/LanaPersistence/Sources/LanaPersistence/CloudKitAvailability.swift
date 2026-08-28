import Foundation

/// Si hay una cuenta de iCloud activa en el dispositivo. `LanaPersistence`
/// lo usa para decidir si `CoreDataExpenseStore` sincroniza con CloudKit o
/// cae a almacenamiento puramente local — sin esto, `NSPersistentCloudKitContainer`
/// sigue funcionando en disco, pero nunca sincroniza (Docs/.claude/skills/cloudkit-sharing:
/// "Si el usuario no tiene sesión, la app cae a modo local... No revientes.").
public enum CloudKitAvailability {
    /// `true` si hay una cuenta de iCloud activa en el dispositivo.
    public static var hasActiveAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}

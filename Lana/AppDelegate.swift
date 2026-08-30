import CloudKit
import LanaPersistence
import UIKit

/// Acepta invitaciones de `CKShare` (ADR-0020) — el único punto de entrada
/// posible es este método de `UIApplicationDelegate`, incluso con la app
/// cerrada al momento del tap en el link. `AppDependencies.live()` es async
/// y puede no haber terminado todavía cuando esto dispara en frío, así que
/// la metadata se encola y se procesa en cuanto `attach(store:)` la conecte.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private var store: CoreDataExpenseStore?
    private var pendingMetadata: [CKShare.Metadata] = []

    func attach(store: CoreDataExpenseStore) {
        self.store = store
        let toProcess = pendingMetadata
        pendingMetadata.removeAll()
        for metadata in toProcess {
            Task { try? await store.acceptShare(metadata) }
        }
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        guard let store else {
            pendingMetadata.append(metadata)
            return
        }
        Task { try? await store.acceptShare(metadata) }
    }
}

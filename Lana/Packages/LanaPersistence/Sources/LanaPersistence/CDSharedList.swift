import CoreData
import Foundation

/// Fila de Core Data para una `SharedList` de `LanaCore` — la raíz del
/// grafo de objetos que se comparte por `CKShare`. Compartir esta entidad
/// (vía `NSPersistentCloudKitContainer.share(_:to:)`) mueve, junto con ella,
/// todos sus `CDEvent` relacionados a la zona de registro nueva que Core
/// Data crea para el share (Docs/.claude/skills/cloudkit-sharing).
@objc(CDSharedList)
public final class CDSharedList: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    /// JSON de `[Participant]` (LanaCore, `Codable`) — el roster completo,
    /// no solo IDs. No hay una entidad `CDParticipant` aparte a propósito
    /// (mismo patrón que `Card.colorHex`: columna plana, no relación) — ver
    /// el ADR de este bloque.
    @NSManaged public var participantsData: Data?
    /// JSON de `SplitRule` (LanaCore, `Codable`).
    @NSManaged public var defaultSplitData: Data?
    @NSManaged public var events: NSSet?
}

public extension CDSharedList {
    /// Fetch request tipado para `CDSharedList`.
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDSharedList> {
        NSFetchRequest<CDSharedList>(entityName: "CDSharedList")
    }
}

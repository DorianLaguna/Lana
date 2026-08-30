import CoreData
import Foundation

/// Fila de Core Data para "cuál participante de una lista compartida soy
/// yo, en este dispositivo" (ADR-0021/ADR-0022). Entidad plana y mutable,
/// **sin relación con `CDSharedList`** a propósito — una relación real la
/// arrastraría al mismo grafo de objetos que `container.share(_:to:)` mueve
/// a la zona compartida (`CDSharedList.swift`), y esto tiene que quedarse
/// siempre en la zona privada del usuario: sincroniza entre los propios
/// dispositivos del usuario vía su CloudKit privado, nunca se comparte con
/// los demás participantes de la lista.
@objc(CDSharedListViewerPreference)
public final class CDSharedListViewerPreference: NSManagedObject {
    @NSManaged public var sharedListID: UUID?
    @NSManaged public var viewerParticipantID: UUID?
}

public extension CDSharedListViewerPreference {
    /// Fetch request tipado para `CDSharedListViewerPreference`.
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDSharedListViewerPreference> {
        NSFetchRequest<CDSharedListViewerPreference>(entityName: "CDSharedListViewerPreference")
    }
}

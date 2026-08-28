import CoreData
import Foundation

/// Fila de Core Data para un `ExpenseEvent` de `LanaCore`. El evento
/// completo viaja serializado en `payload` (JSON vía `Codable`) — `kind`,
/// `date`, `recordedAt` y `sharedListIDValue` son columnas reales para poder
/// filtrar sin decodificar todo. Escrita a mano (no generada por Xcode)
/// porque el codegen automático de Core Data no corre en `swift build` por
/// línea de comandos, y el paquete debe compilar así (Docs/CLAUDE.md).
@objc(CDEvent)
public final class CDEvent: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var kind: String?
    @NSManaged public var date: Date?
    @NSManaged public var recordedAt: Date?
    @NSManaged public var sharedListIDValue: UUID?
    @NSManaged public var payload: Data?
    @NSManaged public var sharedList: CDSharedList?
}

public extension CDEvent {
    /// Fetch request tipado para `CDEvent`.
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDEvent> {
        NSFetchRequest<CDEvent>(entityName: "CDEvent")
    }
}

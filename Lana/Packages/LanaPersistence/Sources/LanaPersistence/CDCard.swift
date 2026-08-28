import CoreData
import Foundation

/// Fila de Core Data para una `Card` de `LanaCore`. Entidad plana y
/// mutable — no un evento (ADR-0014). Escrita a mano, como `CDEvent` y
/// `CDSharedList`, por la misma razón: el codegen de Core Data no corre en
/// `swift build` por línea de comandos.
@objc(CDCard)
public final class CDCard: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var alias: String?
    @NSManaged public var lastFourDigits: String?
    @NSManaged public var limitAmount: NSDecimalNumber?
    @NSManaged public var limitCurrency: String?
    // `NSNumber?`, no `Int16` — una tarjeta de débito no tiene día de
    // corte/pago, y `Int16` no puede representar "sin valor" (caería a 0).
    @NSManaged public var cutoffDay: NSNumber?
    @NSManaged public var dueDay: NSNumber?
    @NSManaged public var kind: String?
    @NSManaged public var colorHex: String?
}

public extension CDCard {
    /// Fetch request tipado para `CDCard`.
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDCard> {
        NSFetchRequest<CDCard>(entityName: "CDCard")
    }
}

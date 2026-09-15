import CoreData
import Foundation

/// Fila de Core Data para un `RecurringItem` de `LanaCore`. Entidad plana y
/// mutable — no un evento (ADR-0014).
@objc(CDRecurringItem)
public final class CDRecurringItem: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var amount: NSDecimalNumber?
    @NSManaged public var currency: String?
    @NSManaged public var kind: String?
    @NSManaged public var category: String?
    @NSManaged public var subcategory: String?
    @NSManaged public var dayOfMonth: Int16
    @NSManaged public var paymentMethodKind: String?
    @NSManaged public var paymentMethodCardID: UUID?
    @NSManaged public var lastRegisteredMonth: Date?
    @NSManaged public var lastAutoRegisteredMonth: Date?
}

public extension CDRecurringItem {
    /// Fetch request tipado para `CDRecurringItem`.
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDRecurringItem> {
        NSFetchRequest<CDRecurringItem>(entityName: "CDRecurringItem")
    }
}

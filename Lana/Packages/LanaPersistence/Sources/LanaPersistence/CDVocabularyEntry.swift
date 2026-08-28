import CoreData
import Foundation

/// Fila de Core Data para un `CorrectionEntry` de `LanaCore` (ADR-0012,
/// ADR-0014). Entidad plana y mutable, sin relación con `CDEvent` — el
/// vocabulario aprendido no es un log, es la última corrección conocida
/// por término.
@objc(CDVocabularyEntry)
public final class CDVocabularyEntry: NSManagedObject {
    @NSManaged public var term: String?
    @NSManaged public var category: String?
    @NSManaged public var correctedAt: Date?
    @NSManaged public var useCount: Int64
}

public extension CDVocabularyEntry {
    /// Fetch request tipado para `CDVocabularyEntry`.
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDVocabularyEntry> {
        NSFetchRequest<CDVocabularyEntry>(entityName: "CDVocabularyEntry")
    }
}

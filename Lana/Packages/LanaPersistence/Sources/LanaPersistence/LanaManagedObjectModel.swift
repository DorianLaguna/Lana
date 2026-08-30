import CoreData

/// El modelo de Core Data, construido en código en vez de con un
/// `.xcdatamodeld` compilado. SwiftPM (`swift build`/`swift test` por línea
/// de comandos, sin Xcode) copia un `.xcdatamodeld` tal cual pero no lo
/// compila a `.momd` — eso requiere `momc`, que solo corre como build phase
/// de Xcode. Como `CLAUDE.md` exige que
/// `swift test --package-path Packages/LanaPersistence` funcione standalone,
/// el modelo vive aquí, no en un recurso.
enum LanaManagedObjectModel {
    /// Una instancia nueva por llamada, a propósito: compartir un mismo
    /// `NSManagedObjectModel` entre varios `NSPersistentContainer` cargados
    /// de forma concurrente (como pasa con tests que corren en paralelo)
    /// crasheó en la práctica — Core Data no lo documenta como seguro entre
    /// containers distintos. El costo es un warning cosmético de Core Data
    /// en consola ("+entity ... unable to disambiguate") cuando muchos
    /// stores conviven en el mismo proceso; no afecta el resultado.
    static func make() -> NSManagedObjectModel {
        let (event, sharedList) = eventAndSharedListEntities()
        // `CDCard` y `CDVocabularyEntry`: entidades planas y mutables, sin
        // relación con `CDEvent` — no son eventos, son dato de referencia
        // editable por CRUD directo (ADR-0014). Viven en el mismo modelo/
        // container que `CDEvent`/`CDSharedList` a propósito, para no repetir
        // el crash de containers concurrentes documentado en este archivo.
        let model = NSManagedObjectModel()
        model.entities = [
            event, sharedList, cardEntity(), vocabularyEntryEntity(), recurringItemEntity(),
            sharedListViewerPreferenceEntity()
        ]
        return model
    }

    private static func eventAndSharedListEntities() -> (event: NSEntityDescription, sharedList: NSEntityDescription) {
        let event = NSEntityDescription()
        event.name = "CDEvent"
        event.managedObjectClassName = NSStringFromClass(CDEvent.self)

        let eventID = attribute("id", type: .UUIDAttributeType)
        let kind = attribute("kind", type: .stringAttributeType)
        let date = attribute("date", type: .dateAttributeType)
        let recordedAt = attribute("recordedAt", type: .dateAttributeType)
        let sharedListIDValue = attribute("sharedListIDValue", type: .UUIDAttributeType)
        let payload = attribute("payload", type: .binaryDataAttributeType)

        let sharedList = NSEntityDescription()
        sharedList.name = "CDSharedList"
        sharedList.managedObjectClassName = NSStringFromClass(CDSharedList.self)

        let sharedListID = attribute("id", type: .UUIDAttributeType)
        let sharedListName = attribute("name", type: .stringAttributeType)
        let participantsData = attribute("participantsData", type: .binaryDataAttributeType)
        let defaultSplitData = attribute("defaultSplitData", type: .binaryDataAttributeType)

        let eventToList = NSRelationshipDescription()
        eventToList.name = "sharedList"
        eventToList.destinationEntity = sharedList
        eventToList.minCount = 0
        eventToList.maxCount = 1
        eventToList.deleteRule = .nullifyDeleteRule
        eventToList.isOptional = true

        let listToEvents = NSRelationshipDescription()
        listToEvents.name = "events"
        listToEvents.destinationEntity = event
        listToEvents.minCount = 0
        listToEvents.maxCount = 0
        listToEvents.deleteRule = .cascadeDeleteRule
        listToEvents.isOptional = true

        eventToList.inverseRelationship = listToEvents
        listToEvents.inverseRelationship = eventToList

        event.properties = [eventID, kind, date, recordedAt, sharedListIDValue, payload, eventToList]
        sharedList.properties = [sharedListID, sharedListName, participantsData, defaultSplitData, listToEvents]
        return (event, sharedList)
    }

    private static func cardEntity() -> NSEntityDescription {
        let card = NSEntityDescription()
        card.name = "CDCard"
        card.managedObjectClassName = NSStringFromClass(CDCard.self)
        card.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("alias", type: .stringAttributeType),
            attribute("lastFourDigits", type: .stringAttributeType),
            attribute("limitAmount", type: .decimalAttributeType),
            attribute("limitCurrency", type: .stringAttributeType),
            attribute("cutoffDay", type: .integer16AttributeType),
            attribute("dueDay", type: .integer16AttributeType),
            attribute("kind", type: .stringAttributeType),
            attribute("colorHex", type: .stringAttributeType)
        ]
        return card
    }

    private static func vocabularyEntryEntity() -> NSEntityDescription {
        let vocabularyEntry = NSEntityDescription()
        vocabularyEntry.name = "CDVocabularyEntry"
        vocabularyEntry.managedObjectClassName = NSStringFromClass(CDVocabularyEntry.self)
        vocabularyEntry.properties = [
            attribute("term", type: .stringAttributeType),
            attribute("category", type: .stringAttributeType),
            attribute("correctedAt", type: .dateAttributeType),
            attribute("useCount", type: .integer64AttributeType)
        ]
        return vocabularyEntry
    }

    private static func recurringItemEntity() -> NSEntityDescription {
        let recurringItem = NSEntityDescription()
        recurringItem.name = "CDRecurringItem"
        recurringItem.managedObjectClassName = NSStringFromClass(CDRecurringItem.self)
        recurringItem.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("name", type: .stringAttributeType),
            attribute("amount", type: .decimalAttributeType),
            attribute("currency", type: .stringAttributeType),
            attribute("kind", type: .stringAttributeType),
            attribute("category", type: .stringAttributeType),
            attribute("subcategory", type: .stringAttributeType),
            attribute("dayOfMonth", type: .integer16AttributeType),
            attribute("paymentMethodKind", type: .stringAttributeType),
            attribute("paymentMethodCardID", type: .UUIDAttributeType),
            attribute("lastRegisteredMonth", type: .dateAttributeType)
        ]
        return recurringItem
    }

    /// Sin relación con `CDSharedList` a propósito — ver el doc comment de
    /// `CDSharedListViewerPreference`: tiene que quedarse en la zona privada,
    /// nunca viajar con la lista a la zona compartida.
    private static func sharedListViewerPreferenceEntity() -> NSEntityDescription {
        let preference = NSEntityDescription()
        preference.name = "CDSharedListViewerPreference"
        preference.managedObjectClassName = NSStringFromClass(CDSharedListViewerPreference.self)
        preference.properties = [
            attribute("sharedListID", type: .UUIDAttributeType),
            attribute("viewerParticipantID", type: .UUIDAttributeType)
        ]
        return preference
    }

    /// Todos los atributos son opcionales: es requisito de CloudKit que cada
    /// columna sea opcional o tenga default (Docs/PLAN.md → Fase 2).
    private static func attribute(_ name: String, type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true
        return attribute
    }
}

import CoreData
import Foundation
import LanaCore

/// `SharedListStore` respaldado por Core Data — mismo actor, mismo
/// container que `ExpenseStore`/`CardStore` (ADR-0014). `SharedList` es
/// dato de referencia editable, no un evento: `save` es un upsert directo
/// sobre la fila `CDSharedList`. Los gastos compartidos en sí se guardan
/// por `ExpenseStore.save(_:)` — este archivo solo cubre la lista y sus
/// liquidaciones.
extension CoreDataExpenseStore: SharedListStore {
    public func save(_ list: SharedList) async throws {
        try await context.perform { [context] in
            let row = try Self.existingSharedListRow(for: list.id, in: context) ?? CDSharedList(context: context)
            row.id = list.id.rawValue
            row.name = list.name
            row.participantsData = try JSONEncoder().encode(list.participants)
            row.defaultSplitData = try JSONEncoder().encode(list.defaultSplit)
            try Self.saveIfNeeded(context)
        }
    }

    public func lists() async throws -> [SharedList] {
        try await context.perform { [context] in
            let rows = try context.fetch(CDSharedList.fetchRequest())
            return rows.compactMap(Self.sharedList(from:)).sorted { $0.name < $1.name }
        }
    }

    /// Borra la lista completa, incluyendo su historial — un borrado
    /// deliberado y más grueso que "borrar un gasto" (que emite una
    /// anulación, ADR-0005). La relación `events` de `CDSharedList` tiene
    /// `deleteRule: .cascade` (`LanaManagedObjectModel`), así que los
    /// `CDEvent` de esta lista se van con ella.
    public func delete(id: SharedListID) async throws {
        try await context.perform { [context] in
            guard let row = try Self.existingSharedListRow(for: id, in: context) else { return }
            context.delete(row)
            try Self.saveIfNeeded(context)
        }
    }

    public func recordSettlement(_ settlement: SettlementRecorded) async throws {
        try await context.perform { [context] in
            try Self.insert(.settlementRecorded(settlement), in: context)
            try Self.saveIfNeeded(context)
        }
    }

    // `events()` no se implementa aquí — `CoreDataCardPaymentStore.swift`
    // ya la implementa con la misma firma exacta que pide `SharedListStore`
    // (el log completo, sin filtrar), y sirve para las dos conformancias a
    // la vez: mismo actor, mismo método, dos protocolos que lo requieren.

    /// `internal`, no `private` — `CoreDataExpenseStore.insert(_:in:)`
    /// también lo usa, para enlazar un `CDEvent` compartido a su
    /// `CDSharedList` vía la relación real (no solo `sharedListIDValue`),
    /// que es lo que `NSPersistentCloudKitContainer.share(_:to:)` necesita
    /// para mover los eventos junto con la lista al compartir (Fase 8, G3).
    static func existingSharedListRow(
        for id: SharedListID,
        in context: NSManagedObjectContext) throws -> CDSharedList? {
        let request = CDSharedList.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id.rawValue as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func sharedList(from row: CDSharedList) -> SharedList? {
        guard let id = row.id, let name = row.name else { return nil }
        let decoder = JSONDecoder()
        let participants = row.participantsData.flatMap { try? decoder.decode([Participant].self, from: $0) } ?? []
        let defaultSplit = row.defaultSplitData.flatMap { try? decoder.decode(SplitRule.self, from: $0) } ?? .payerOnly
        return SharedList(
            id: SharedListID(rawValue: id),
            name: name,
            participants: participants,
            defaultSplit: defaultSplit)
    }
}

import CoreData
import Foundation
import LanaCore

/// Persiste `SharedListStore.viewerParticipantID(for:)` en
/// `CDSharedListViewerPreference` — sin relación con `CDSharedList`, para
/// que nunca viaje a la zona compartida al invitar (ver el doc comment de
/// esa entidad, ADR-0021/ADR-0022).
public extension CoreDataExpenseStore {
    /// Qué participante es "yo" para `id`, en este dispositivo. `nil` si
    /// nunca se marcó.
    func viewerParticipantID(for id: SharedListID) async throws -> ParticipantID? {
        try await context.perform { [context] in
            try Self.existingViewerPreferenceRow(for: id, in: context)?.viewerParticipantID
                .map { ParticipantID(rawValue: $0) }
        }
    }

    /// Marca cuál participante es "yo" para `id`.
    func setViewerParticipantID(_ participantID: ParticipantID, for id: SharedListID) async throws {
        try await context.perform { [context] in
            let row = try Self.existingViewerPreferenceRow(for: id, in: context) ?? CDSharedListViewerPreference(
                context: context)
            row.sharedListID = id.rawValue
            row.viewerParticipantID = participantID.rawValue
            try Self.saveIfNeeded(context)
        }
    }

    private static func existingViewerPreferenceRow(
        for id: SharedListID,
        in context: NSManagedObjectContext) throws -> CDSharedListViewerPreference? {
        let request = CDSharedListViewerPreference.fetchRequest()
        request.predicate = NSPredicate(format: "sharedListID == %@", id.rawValue as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

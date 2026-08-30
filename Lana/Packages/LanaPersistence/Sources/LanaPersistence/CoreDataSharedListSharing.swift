import CloudKit
import CoreData
import Foundation
import LanaCore

/// G3 (ADR-0020): `CKShare` real sobre `CDSharedList`. Compartir esta
/// entidad mueve, junto con ella, todos sus `CDEvent` relacionados a la zona
/// de registro nueva que Core Data crea para el share (doc comment de
/// `CDSharedList.swift`) — nada de esto toca el roster de `Participant`,
/// que sigue siendo local hasta que exista una razón real para
/// reconciliarlo contra identidad de CKShare (ADR-0017).
public extension CoreDataExpenseStore {
    /// Prepara (o reutiliza) la invitación de `CKShare` para esta lista y
    /// regresa la URL para invitar por share sheet. `nil` si el store se
    /// construyó sin CloudKit (`cloudKitContainerIdentifier == nil` — sin
    /// cuenta de iCloud activa al momento de abrir la app). No vuelve a
    /// checar la cuenta aquí: la decisión real ya quedó fija al cargar el
    /// store (`NSPersistentCloudKitContainerOptions` no se puede cambiar
    /// sobre un store ya cargado), así que si la cuenta cambió después de
    /// abrir la app, la señal correcta es reabrir la app, no re-consultar
    /// `CloudKitAvailability` aquí sin poder hacer nada distinto con eso.
    func shareURL(for id: SharedListID) async throws -> URL? {
        guard cloudKitContainerIdentifier != nil else { return nil }
        let container = container
        let context = context

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    guard let row = try Self.existingSharedListRow(for: id, in: context) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let listName = row.name

                    // Un registro solo puede estar en un share a la vez —
                    // reutilizar el existente evita el error conocido
                    // `alreadyShared` si el usuario toca "Invitar" dos veces
                    // (Docs/.claude/skills/cloudkit-sharing).
                    if let existingShare = try? container.fetchShares(matching: [row.objectID])[row.objectID] {
                        continuation.resume(returning: existingShare.url)
                        return
                    }

                    container.share([row], to: nil) { _, share, _, error in
                        if let error {
                            continuation.resume(throwing: Self.sharingError(from: error))
                            return
                        }
                        guard let share else {
                            continuation.resume(returning: nil)
                            return
                        }
                        share[CKShare.SystemFieldKey.title] = listName
                        // Solo por invitación explícita, nunca un link
                        // público que cualquiera pudiera usar.
                        share.publicPermission = .none
                        guard let persistentStore = container.persistentStoreCoordinator.persistentStores.first else {
                            continuation.resume(returning: share.url)
                            return
                        }
                        container.persistUpdatedShare(share, in: persistentStore) { updatedShare, persistError in
                            if let persistError {
                                continuation.resume(throwing: Self.sharingError(from: persistError))
                            } else {
                                continuation.resume(returning: (updatedShare ?? share).url)
                            }
                        }
                    }
                } catch {
                    continuation.resume(throwing: Self.sharingError(from: error))
                }
            }
        }
    }

    /// Nunca se le muestra al usuario un `CKError` crudo — es un bloque de
    /// texto con UUIDs de registro y errores parciales anidados, ilegible
    /// (visto en producción: un `.quotaExceeded` envuelto en
    /// `.partialFailure` al compartir una lista con mucho historial, porque
    /// compartir mueve todos sus `CDEvent` de golpe a la zona nueva — ver
    /// doc comment de `shareURL(for:)`). Se traduce a `PersistenceError`,
    /// que si `LanaPersistence` no importara nada, viviría en `LanaCore` —
    /// pero como el resto de las siglas de `CKError` sí necesitan
    /// `CloudKit`, la traducción se queda aquí.
    private static func sharingError(from error: Error) -> Error {
        guard let ckError = error as? CKError else { return error }
        if let retryAfter = quotaExceededRetryAfter(in: ckError) {
            return PersistenceError.cloudKitQuotaExceeded(retryAfterSeconds: retryAfter)
        }
        return PersistenceError.cloudKitSharingFailed
    }

    private static func quotaExceededRetryAfter(in error: CKError) -> TimeInterval? {
        if error.code == .quotaExceeded {
            return error.retryAfterSeconds
        }
        guard error.code == .partialFailure, let partials = error.partialErrorsByItemID else { return nil }
        for case let underlying as CKError in partials.values where underlying.code == .quotaExceeded {
            return underlying.retryAfterSeconds ?? 0
        }
        return nil
    }

    /// Llamado desde `AppDelegate.application(_:userDidAcceptCloudKitShareWith:)`
    /// — nunca desde una feature, no vive en `SharedListStore` (ADR-0020).
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        let container = container
        guard let persistentStore = container.persistentStoreCoordinator.persistentStores.first else {
            throw PersistenceError.noPersistentStore
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.acceptShareInvitations(from: [metadata], into: persistentStore) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

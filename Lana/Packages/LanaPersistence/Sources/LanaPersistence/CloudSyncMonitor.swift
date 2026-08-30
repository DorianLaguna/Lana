import CoreData
import Foundation
import LanaCore

/// `SyncStatusReporting` real: deriva el estado de los eventos que
/// `NSPersistentCloudKitContainer` reporta por notificación, nunca solo de
/// si hay cuenta de iCloud activa — ver el doc comment de `SyncStatus`
/// (ADR-0020).
public actor CloudSyncMonitor: SyncStatusReporting {
    public private(set) var currentStatus: SyncStatus = .syncing
    private var continuations: [UUID: AsyncStream<SyncStatus>.Continuation] = [:]
    private var lastKnownGood: Date?
    private let containerIdentifier: String

    /// - Parameter containerIdentifier: mismo identificador que
    ///   `CoreDataExpenseStore.live(cloudKitContainerIdentifier:)` — el
    ///   estado real de la cuenta se checa dentro de `observe()`, de forma
    ///   asíncrona (`CloudKitAvailability.hasActiveAccount(containerIdentifier:)`);
    ///   `currentStatus` arranca en `.syncing` de forma optimista y
    ///   `observe()` lo corrige a `.disabled` de inmediato si no hay cuenta.
    public init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
        Task { await self.observe() }
    }

    public nonisolated func statusUpdates() -> AsyncStream<SyncStatus> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id: id, continuation: continuation) }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.unregister(id: id) }
            }
        }
    }

    private func register(id: UUID, continuation: AsyncStream<SyncStatus>.Continuation) {
        continuations[id] = continuation
        continuation.yield(currentStatus)
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func observe() async {
        guard await CloudKitAvailability.hasActiveAccount(containerIdentifier: containerIdentifier) else {
            update(.disabled)
            return
        }
        let notifications = NotificationCenter.default.notifications(
            named: NSPersistentCloudKitContainer.eventChangedNotification)
        for await notification in notifications {
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ]
                as? NSPersistentCloudKitContainer.Event
            else { continue }

            guard let endDate = event.endDate else {
                update(.syncing)
                continue
            }
            if event.succeeded {
                lastKnownGood = endDate
                update(.synced(lastSuccess: endDate))
            } else {
                update(.failed(lastKnownGood: lastKnownGood))
            }
        }
    }

    private func update(_ status: SyncStatus) {
        currentStatus = status
        for continuation in continuations.values {
            continuation.yield(status)
        }
    }
}

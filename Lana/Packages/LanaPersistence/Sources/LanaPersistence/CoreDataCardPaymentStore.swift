import CoreData
import Foundation
import LanaCore

/// `CardPaymentStore` respaldado por Core Data — mismo actor, mismo
/// container que `ExpenseStore`/`CardStore` (ADR-0014). Un pago a tarjeta
/// es un evento más en el mismo log append-only (ADR-0005), no una fila
/// mutable aparte.
extension CoreDataExpenseStore: CardPaymentStore {
    public func recordPayment(_ payment: CardPaymentRecorded) async throws {
        try await context.perform { [context] in
            try Self.insert(.cardPaymentRecorded(payment), in: context)
            try Self.saveIfNeeded(context)
        }
    }

    /// `SharedListStore` (`CoreDataSharedListStore.swift`) pide exactamente
    /// la misma firma para su propio `events()` — esta única implementación
    /// satisface a los dos protocolos, mismo actor.
    public func events() async throws -> [ExpenseEvent] {
        try await context.perform { [context] in
            try Self.allEvents(in: context)
        }
    }
}

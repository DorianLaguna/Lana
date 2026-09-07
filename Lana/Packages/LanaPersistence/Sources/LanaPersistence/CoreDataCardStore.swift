import CoreData
import Foundation
import LanaCore

/// `CardStore` respaldado por Core Data — mismo actor, mismo container que
/// `ExpenseStore` (ADR-0014). `Card` es dato de referencia editable, no un
/// evento: `save` es un upsert directo sobre la fila `CDCard`.
extension CoreDataExpenseStore: CardStore {
    public func save(_ card: Card) async throws {
        try await context.perform { [context] in
            let row = try Self.existingCardRow(for: card.id, in: context) ?? CDCard(context: context)
            row.id = card.id.rawValue
            row.alias = card.alias
            row.walletMatchHint = card.walletMatchHint
            row.lastFourDigits = card.lastFourDigits
            row.limitAmount = card.limit.map { $0.amount as NSDecimalNumber }
            row.limitCurrency = card.limit?.currency.rawValue
            row.cutoffDay = card.cutoffDay.map { NSNumber(value: $0) }
            row.dueDay = card.dueDay.map { NSNumber(value: $0) }
            row.kind = card.kind.rawValue
            row.colorHex = card.colorHex
            try Self.saveIfNeeded(context)
        }
    }

    public func cards() async throws -> [Card] {
        try await context.perform { [context] in
            let rows = try context.fetch(CDCard.fetchRequest())
            return rows.compactMap(Self.card(from:)).sorted { $0.alias < $1.alias }
        }
    }

    public func delete(id: CardID) async throws {
        try await context.perform { [context] in
            guard let row = try Self.existingCardRow(for: id, in: context) else { return }
            context.delete(row)
            try Self.saveIfNeeded(context)
        }
    }

    private static func existingCardRow(for id: CardID, in context: NSManagedObjectContext) throws -> CDCard? {
        let request = CDCard.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id.rawValue as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func card(from row: CDCard) -> Card? {
        // `lastFourDigits` no entra a este guard — es opcional de verdad, no
        // un dato requerido que falte. `limit`/`cutoffDay`/`dueDay` tampoco:
        // una tarjeta de débito no los tiene.
        guard let id = row.id, let alias = row.alias else { return nil }
        let limit: Money? = if let limitAmount = row.limitAmount, let limitCurrency = row.limitCurrency {
            Money(amount: limitAmount as Decimal, currency: Currency(rawValue: limitCurrency))
        } else {
            nil
        }
        return try? Card(
            id: CardID(rawValue: id),
            alias: alias,
            walletMatchHint: row.walletMatchHint,
            lastFourDigits: row.lastFourDigits ?? "",
            limit: limit,
            cutoffDay: row.cutoffDay?.intValue,
            dueDay: row.dueDay?.intValue,
            // Filas guardadas antes de que estas dos columnas existieran no
            // las tienen — caen al default de `Card.init`, no a un error.
            kind: row.kind.flatMap(CardKind.init(rawValue:)) ?? .credit,
            colorHex: row.colorHex ?? "#1B4FD8")
    }
}

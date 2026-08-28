import CoreData
import Foundation
import LanaCore

/// `RecurringItemStore` respaldado por Core Data — mismo actor, mismo
/// container que `ExpenseStore`/`CardStore` (ADR-0014).
extension CoreDataExpenseStore: RecurringItemStore {
    public func save(_ item: RecurringItem) async throws {
        try await context.perform { [context] in
            let row = try Self.existingRecurringItemRow(for: item.id, in: context) ?? CDRecurringItem(context: context)
            row.id = item.id.rawValue
            row.name = item.name
            row.amount = item.amount.amount as NSDecimalNumber
            row.currency = item.amount.currency.rawValue
            row.kind = item.kind == .income ? "income" : "expense"
            row.category = item.category
            row.dayOfMonth = Int16(item.dayOfMonth)
            switch item.paymentMethod {
            case .cash:
                row.paymentMethodKind = "cash"
                row.paymentMethodCardID = nil
            case let .debit(cardID):
                row.paymentMethodKind = "debit"
                row.paymentMethodCardID = cardID.rawValue
            case let .credit(cardID):
                row.paymentMethodKind = "credit"
                row.paymentMethodCardID = cardID.rawValue
            case .transfer:
                row.paymentMethodKind = "transfer"
                row.paymentMethodCardID = nil
            case nil:
                row.paymentMethodKind = nil
                row.paymentMethodCardID = nil
            }
            row.lastRegisteredMonth = item.lastRegisteredMonth
            try Self.saveIfNeeded(context)
        }
    }

    public func items() async throws -> [RecurringItem] {
        try await context.perform { [context] in
            let rows = try context.fetch(CDRecurringItem.fetchRequest())
            return rows.compactMap(Self.recurringItem(from:)).sorted { $0.dayOfMonth < $1.dayOfMonth }
        }
    }

    public func delete(id: RecurringItemID) async throws {
        try await context.perform { [context] in
            guard let row = try Self.existingRecurringItemRow(for: id, in: context) else { return }
            context.delete(row)
            try Self.saveIfNeeded(context)
        }
    }

    private static func existingRecurringItemRow(
        for id: RecurringItemID,
        in context: NSManagedObjectContext) throws -> CDRecurringItem? {
        let request = CDRecurringItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id.rawValue as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func recurringItem(from row: CDRecurringItem) -> RecurringItem? {
        guard let id = row.id, let name = row.name, let amount = row.amount,
              let currency = row.currency, let kind = row.kind else { return nil }
        let paymentMethod: PaymentMethod? = switch row.paymentMethodKind {
        case "cash": .cash
        case "debit": row.paymentMethodCardID.map { PaymentMethod.debit(cardID: CardID(rawValue: $0)) }
        case "credit": row.paymentMethodCardID.map { PaymentMethod.credit(cardID: CardID(rawValue: $0)) }
        case "transfer": .transfer
        default: nil
        }
        return try? RecurringItem(
            id: RecurringItemID(rawValue: id),
            name: name,
            amount: Money(amount: amount as Decimal, currency: Currency(rawValue: currency)),
            kind: kind == "income" ? .income : .expense,
            category: row.category,
            dayOfMonth: Int(row.dayOfMonth),
            paymentMethod: paymentMethod,
            lastRegisteredMonth: row.lastRegisteredMonth)
    }
}

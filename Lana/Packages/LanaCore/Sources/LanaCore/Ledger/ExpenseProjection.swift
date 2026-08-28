import Foundation

/// Proyecta un stream de eventos al estado actual de cada transacción — ya
/// con sus correcciones aplicadas y sin las anuladas ni los pagos de
/// tarjeta (que no son transacciones, `CardPaymentRecorded`). Es lo que
/// `ExpenseStore.expenses(in:)` necesita para responder sin guardar nada
/// mutable (ADR-0005): el `ExpenseID` de cada resultado es el mismo `EventID`
/// del evento raíz que lo originó.
public enum ExpenseProjection {
    /// Las transacciones vigentes de `events` — sin anuladas ni pagos de tarjeta.
    public static func expenses(from events: [ExpenseEvent]) -> [Expense] {
        LedgerFold.resolve(events).values.compactMap { transaction in
            guard !transaction.isVoided, transaction.kind != .cardPayment else { return nil }
            return Expense(
                id: ExpenseID(rawValue: transaction.id.rawValue),
                kind: transaction.kind == .income ? .income : .expense,
                amount: transaction.amount,
                concept: transaction.concept,
                category: transaction.category,
                subcategory: transaction.subcategory,
                date: transaction.date,
                paymentMethod: transaction.paymentMethod,
                needsReview: transaction.needsReview,
                sharedListID: transaction.sharedListID,
                payer: transaction.payer,
                split: transaction.split)
        }
    }
}

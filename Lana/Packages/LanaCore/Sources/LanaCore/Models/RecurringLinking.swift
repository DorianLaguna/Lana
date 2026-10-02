import Foundation

/// "¿Esto es tu Netflix?": un movimiento registrado sin vínculo a su
/// recurrente que se parece a uno (ADR-0061). Es solo una pregunta: el
/// vínculo existe hasta que el usuario lo confirma en "Por revisar".
public struct RecurringLinkSuggestion: Identifiable, Sendable, Hashable {
    public let expense: Expense
    public let item: RecurringItem

    public var id: ExpenseID {
        expense.id
    }

    public init(expense: Expense, item: RecurringItem) {
        self.expense = expense
        self.item = item
    }
}

/// Encuentra los movimientos que salieron de un recurrente pero no lo dicen:
/// lo registrado antes de que existiera el vínculo (ADR-0042) o lo dictado a
/// mano. Lana no los liga sola; los propone (ADR-0061).
public enum RecurringLinking {
    /// Una sugerencia por movimiento y, como un recurrente cae una vez al mes,
    /// a lo más una por recurrente y mes, la más vieja primero.
    ///
    /// Se parece quien es del mismo tipo (gasto o ingreso) y moneda, y se
    /// llama igual que el recurrente —sin importar mayúsculas ni acentos— o
    /// uno contiene al otro y el monto es el mismo. Un nombre igual gana
    /// sobre uno contenido.
    ///
    /// No se sugiere lo que ya está ligado, lo que todavía espera revisión
    /// (primero se confirma qué es), lo que el usuario ya dijo que no es de
    /// ese recurrente, ni un recurrente que ya tiene su movimiento ese mes.
    public static func suggestions(
        for expenses: [Expense],
        recurringItems: [RecurringItem],
        calendar: Calendar = .current) -> [RecurringLinkSuggestion] {
        var taken = Set(expenses.compactMap { expense in
            expense.recurringItemID.flatMap { MonthKey(item: $0, date: expense.date, calendar: calendar) }
        })
        var result: [RecurringLinkSuggestion] = []
        for expense in expenses.sorted(by: { $0.date < $1.date })
            where expense.recurringItemID == nil && !expense.needsReview {
            let candidates = recurringItems.filter { item in
                guard let key = MonthKey(item: item.id, date: expense.date, calendar: calendar) else { return false }
                return item.kind == expense.kind
                    && !expense.declinedRecurringItemIDs.contains(item.id)
                    && !taken.contains(key)
            }
            guard let item = bestMatch(for: expense, in: candidates),
                  let key = MonthKey(item: item.id, date: expense.date, calendar: calendar) else { continue }
            taken.insert(key)
            result.append(RecurringLinkSuggestion(expense: expense, item: item))
        }
        return result
    }

    private struct MonthKey: Hashable {
        let item: RecurringItemID
        let month: Date

        init?(item: RecurringItemID, date: Date, calendar: Calendar) {
            guard let month = calendar.dateInterval(of: .month, for: date)?.start else { return nil }
            self.item = item
            self.month = month
        }
    }

    private static func bestMatch(for expense: Expense, in items: [RecurringItem]) -> RecurringItem? {
        let concept = folded(expense.concept)
        guard !concept.isEmpty else { return nil }
        let sameCurrency = items.filter { $0.amount.currency == expense.amount.currency }
        if let exact = sameCurrency.first(where: { folded($0.name) == concept }) {
            return exact
        }
        return sameCurrency.first { item in
            let name = folded(item.name)
            return !name.isEmpty && (concept.contains(name) || name.contains(concept))
                && item.amount.amount == expense.amount.amount
        }
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

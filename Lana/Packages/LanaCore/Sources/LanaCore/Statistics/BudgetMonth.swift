import Foundation

/// A qué mes le cuenta un movimiento en "Te queda" (ADR-0060).
///
/// **Lo que se paga con tarjeta de crédito cuenta en el mes en que cierra su
/// ciclo**, no en el que se compró: con corte el 23, lo comprado el 24 de
/// septiembre se junta para el corte de octubre, y es octubre el que lo
/// carga. Es la misma regla con la que el desglose de Hoy ya decía "para el
/// mes que entra" (ADR-0046, enmienda 3); aquí se aplica también a la cifra.
///
/// Todo lo demás —débito, efectivo, transferencia, ingresos, y una tarjeta que
/// ya se borró— cuenta en el mes calendario de su fecha.
public enum BudgetMonth {
    /// El primer día del mes al que le cuenta `expense`.
    public static func month(of expense: Expense, cards: [Card], calendar: Calendar = .current) -> Date? {
        let date = cycleEnd(of: expense, cards: cards, calendar: calendar) ?? expense.date
        return calendar.dateInterval(of: .month, for: date)?.start
    }

    /// Los movimientos de `expenses` que le cuentan al mes de `month`.
    ///
    /// `expenses` tiene que cubrir desde el inicio del mes **anterior**: una
    /// compra con tarjeta hecha después del corte de ese mes le cuenta a este.
    public static func expenses(
        _ expenses: [Expense],
        countingIn month: Date,
        cards: [Card],
        calendar: Calendar = .current) -> [Expense] {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        return expenses.filter { self.month(of: $0, cards: cards, calendar: calendar) == start }
    }

    /// Dónde cierra el ciclo de la tarjeta de crédito con que se pagó. `nil`
    /// si no se pagó con crédito o la tarjeta ya no existe.
    private static func cycleEnd(of expense: Expense, cards: [Card], calendar: Calendar) -> Date? {
        guard expense.kind == .expense, case let .credit(cardID) = expense.paymentMethod,
              let card = cards.first(where: { $0.id == cardID }),
              card.kind == .credit,
              let cutoffDay = card.cutoffDay else { return nil }
        return StatementCycle.containing(expense.date, cutoffDay: cutoffDay, calendar: calendar).end
    }
}

import Foundation

/// Pliega los eventos de gastos con tarjeta de crédito en saldos por
/// tarjeta, separados en ciclo abierto (lo que se sigue acumulando) y
/// último estado de cuenta (lo ya facturado, con fecha límite de pago).
///
/// Deuda con tarjetas (este tipo) y deuda con personas (`PersonLedger`) son
/// ledgers independientes que **nunca** se suman ni se mezclan
/// (Docs/CLAUDE.md). El débito no entra aquí — es dinero real saliendo, no
/// genera deuda con el banco.
public struct CardLedger: Sendable {
    private let events: [ExpenseEvent]

    public init(events: [ExpenseEvent] = []) {
        self.events = events
    }

    public func appending(_ event: ExpenseEvent) -> CardLedger {
        CardLedger(events: events + [event])
    }

    /// Suma de cargos de crédito a `card` en el ciclo de corte que contiene
    /// `date` — lo que se sigue acumulando y todavía no se factura. `0` en
    /// débito, que no tiene ciclo de corte.
    public func currentCycleBalance(for card: Card, asOf date: Date, calendar: Calendar = .current) -> Money {
        guard let cutoffDay = card.cutoffDay, let limit = card.limit else {
            return Money(amount: 0, currency: .mxn)
        }
        let cycle = StatementCycle.containing(date, cutoffDay: cutoffDay, calendar: calendar)
        return sumCharges(to: card.id, in: cycle, currency: limit.currency)
    }

    /// Suma de cargos de crédito a `card` en el ciclo de corte inmediatamente
    /// anterior a `date` — lo ya facturado, con fecha límite de pago. `0` en
    /// débito, que no tiene ciclo de corte.
    public func lastStatementBalance(for card: Card, asOf date: Date, calendar: Calendar = .current) -> Money {
        guard let cutoffDay = card.cutoffDay, let limit = card.limit else {
            return Money(amount: 0, currency: .mxn)
        }
        let currentCycle = StatementCycle.containing(date, cutoffDay: cutoffDay, calendar: calendar)
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: currentCycle.start) ?? currentCycle.start
        let previousCycle = StatementCycle.containing(dayBefore, cutoffDay: cutoffDay, calendar: calendar)
        return sumCharges(to: card.id, in: previousCycle, currency: limit.currency)
    }

    /// Lo que falta pagar del último estado de cuenta: lo facturado en ese
    /// corte menos los pagos hechos a `card` desde ese corte hasta `date`
    /// (`CardPaymentRecorded` — Docs/DATA-FLOW.md). No asigna pagos a un
    /// corte específico más allá de eso; la asignación fina es trabajo de
    /// Fase 7.5. `0` en débito, que no tiene ciclo de corte.
    public func outstandingStatementBalance(for card: Card, asOf date: Date, calendar: Calendar = .current) -> Money {
        guard let cutoffDay = card.cutoffDay, let limit = card.limit else {
            return Money(amount: 0, currency: .mxn)
        }
        let currentCycle = StatementCycle.containing(date, cutoffDay: cutoffDay, calendar: calendar)
        let billed = lastStatementBalance(for: card, asOf: date, calendar: calendar)
        let paymentWindow = StatementCycle(start: currentCycle.start, end: date)
        let paid = sumPayments(to: card.id, in: paymentWindow, currency: limit.currency)
        return (try? billed - paid) ?? billed
    }

    private func sumCharges(to cardID: CardID, in cycle: StatementCycle, currency: Currency) -> Money {
        let resolved = LedgerFold.resolve(events)
        let total = resolved.values
            .filter { transaction in
                guard transaction.kind == .expense, !transaction.isVoided else { return false }
                guard case let .credit(id) = transaction.paymentMethod else { return false }
                return id == cardID && cycle.contains(transaction.date)
            }
            .reduce(Decimal(0)) { $0 + $1.amount.amount }
        return Money(amount: total, currency: currency)
    }

    private func sumPayments(to cardID: CardID, in cycle: StatementCycle, currency: Currency) -> Money {
        let resolved = LedgerFold.resolve(events)
        let total = resolved.values
            .filter { transaction in
                guard transaction.kind == .cardPayment, !transaction.isVoided else { return false }
                return transaction.cardID == cardID && cycle.contains(transaction.date)
            }
            .reduce(Decimal(0)) { $0 + $1.amount.amount }
        return Money(amount: total, currency: currency)
    }
}

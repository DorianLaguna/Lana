import Foundation

/// De qué está hecho lo que queda del mes: los recurrentes que faltan por
/// cobrarse y, aparte, lo que hay que hacer con cada tarjeta (ADR-0045,
/// ADR-0046).
///
/// **Los recurrentes y las tarjetas no se mezclan.** Un recurrente pendiente es
/// dinero que va a salir este mes y punto; una tarjeta puede estar en dos
/// situaciones distintas a la vez —lo ya facturado que toca pagar, y lo que se
/// sigue acumulando para el corte que no cierra— y meterlas en la misma bolsa
/// borra esa diferencia, que es justo la que importa para saber cuánto se puede
/// gastar hoy.
///
/// No reimplementa aritmética: los recurrentes salen de
/// `commitments(from:registeredIn:asOf:)` (ADR-0039) y las tarjetas de
/// `CardLedger`, la misma fuente que el detalle de cada tarjeta.
public struct MonthCommitments: Sendable, Equatable {
    /// De dónde sale el cálculo. Van juntos porque siempre se leen juntos, y
    /// porque quien llama ya los tiene cargados del mismo mes.
    public struct Inputs: Sendable {
        public let recurringItems: [RecurringItem]
        /// Los movimientos del mes, para no contar dos veces uno que ya se
        /// registró (`RecurringItem.registration(in:forMonthOf:)`).
        public let expenses: [Expense]
        public let cards: [Card]
        /// Con qué se calcula lo facturado y lo que se acumula.
        public let ledger: CardLedger

        public init(
            recurringItems: [RecurringItem] = [],
            expenses: [Expense] = [],
            cards: [Card] = [],
            ledger: CardLedger = CardLedger(events: [])) {
            self.recurringItems = recurringItems
            self.expenses = expenses
            self.cards = cards
            self.ledger = ledger
        }
    }

    /// Una tarjeta de crédito y sus dos cifras, que nunca se suman entre sí.
    public struct CardBalance: Sendable, Hashable, Identifiable {
        public var id: String {
            card
        }

        /// El alias, como lo nombró su dueño.
        public let card: String
        /// El día de corte, que es lo que explica por qué una cifra es de este
        /// mes y la otra del siguiente.
        public let cutoffDay: Int?
        /// Lo ya facturado en el último corte y todavía sin pagar. **Se paga
        /// este mes**, aunque su día límite ya haya pasado: seguir debiéndolo
        /// no deja de ser deuda porque se venció la fecha.
        public let dueThisMonth: Money
        /// Lo que se lleva acumulado en el ciclo abierto. Se factura en el
        /// próximo corte, así que **se paga el mes que entra** y no se resta de
        /// este. Va a crecer mientras se siga usando la tarjeta.
        public let nextMonth: Money

        public init(card: String, cutoffDay: Int?, dueThisMonth: Money, nextMonth: Money) {
            self.card = card
            self.cutoffDay = cutoffDay
            self.dueThisMonth = dueThisMonth
            self.nextMonth = nextMonth
        }

        /// `false` cuando no hay nada que decir de esta tarjeta.
        public var hasSomethingToSay: Bool {
            dueThisMonth.amount > 0 || nextMonth.amount > 0
        }
    }

    /// La moneda de estas cifras. Nunca se mezclan (Docs/CONVENTIONS.md).
    public let currency: Currency
    /// Los recurrentes que faltan en el mes, del más próximo al más lejano.
    /// **Esto, y solo esto, es lo comprometido.**
    public let recurring: [Commitment]
    /// Las tarjetas con algo que decir, de mayor a menor deuda de este mes.
    public let cards: [CardBalance]
    /// Salidas que caen **justo después** del mes. Se muestran para que nadie
    /// se gaste la renta del 1 estando a día 28, pero no entran a la suma.
    public let justAfter: [Commitment]

    /// - Parameters:
    ///   - month: cualquier fecha del mes que se está viendo.
    ///   - currency: la moneda a resolver.
    ///   - inputs: recurrentes, movimientos del mes, tarjetas y ledger.
    ///   - asOf: qué momento es "ahora". Lo ya pasado no es un compromiso.
    ///   - lookaheadDays: cuántos días después del mes se asoman en `justAfter`.
    public static func resolve(
        month: Date,
        currency: Currency,
        from inputs: Inputs,
        asOf: Date = Date(),
        lookaheadDays: Int = 7,
        calendar: Calendar = .current) -> MonthCommitments {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            return MonthCommitments(currency: currency, recurring: [], cards: [], justAfter: [])
        }
        let monthPeriod = PayPeriod(start: interval.start, end: interval.end, isAnchoredToIncome: false)
        let recurring = monthPeriod.commitments(
            from: inputs.recurringItems,
            registeredIn: inputs.expenses,
            asOf: asOf,
            calendar: calendar)

        let afterEnd = calendar.date(byAdding: .day, value: lookaheadDays, to: interval.end) ?? interval.end
        let afterPeriod = PayPeriod(start: interval.end, end: afterEnd, isAnchoredToIncome: false)
        let after = afterPeriod.commitments(
            from: inputs.recurringItems,
            registeredIn: inputs.expenses,
            asOf: asOf,
            calendar: calendar)

        return MonthCommitments(
            currency: currency,
            recurring: Self.outflows(recurring, in: currency),
            cards: Self.balances(in: inputs, currency: currency, asOf: asOf, calendar: calendar),
            justAfter: Self.outflows(after, in: currency))
    }

    /// Lo que hay que decir de cada tarjeta de crédito.
    ///
    /// **No se filtra por día límite.** El código anterior exigía que la fecha
    /// límite no hubiera pasado todavía, así que una tarjeta que se seguía
    /// debiendo desaparecía de la pantalla en cuanto se vencía — que es cuando
    /// más importa verla.
    private static func balances(
        in inputs: Inputs,
        currency: Currency,
        asOf: Date,
        calendar: Calendar) -> [CardBalance] {
        inputs.cards
            .compactMap { card -> CardBalance? in
                guard card.kind == .credit else { return nil }
                let due = inputs.ledger.outstandingStatementBalance(for: card, asOf: asOf, calendar: calendar)
                let next = inputs.ledger.currentCycleBalance(for: card, asOf: asOf, calendar: calendar)
                guard due.currency == currency || next.currency == currency else { return nil }
                let balance = CardBalance(
                    card: card.alias,
                    cutoffDay: card.cutoffDay,
                    dueThisMonth: due,
                    nextMonth: next)
                return balance.hasSomethingToSay ? balance : nil
            }
            .sorted { first, second in
                first.dueThisMonth.amount == second.dueThisMonth.amount
                    ? first.card < second.card
                    : first.dueThisMonth.amount > second.dueThisMonth.amount
            }
    }

    /// Solo lo que sale, y solo en esta moneda. Un ingreso por venir se queda
    /// fuera a propósito: lo que queda cuenta lo registrado, no lo prometido.
    private static func outflows(_ commitments: [Commitment], in currency: Currency) -> [Commitment] {
        commitments
            .filter { $0.amount.currency == currency && $0.amount.amount < 0 }
            .sorted { $0.date < $1.date }
    }

    /// Lo comprometido: **los recurrentes pendientes del mes**. Las tarjetas no
    /// entran aquí — tienen su propio renglón porque su dinero no sale igual.
    public var committed: Decimal {
        recurring.reduce(Decimal(0)) { $0 + abs($1.amount.amount) }
    }

    /// Lo que hay que pagarles a las tarjetas este mes.
    public var cardsDueThisMonth: Decimal {
        cards.reduce(Decimal(0)) { $0 + $1.dueThisMonth.amount }
    }

    /// Lo que se acumula para el mes que entra. Se muestra, no se resta.
    public var cardsNextMonth: Decimal {
        cards.reduce(Decimal(0)) { $0 + $1.nextMonth.amount }
    }

    /// Lo libre después de los recurrentes comprometidos.
    public func free(after remaining: Decimal) -> Decimal {
        remaining - committed
    }

    /// Lo que de verdad queda después de pagarle a las tarjetas. **Puede ser
    /// negativo**, y eso es el dato: significa que el mes no cierra sin el
    /// ingreso que todavía no cae.
    public func afterCards(from remaining: Decimal) -> Decimal {
        free(after: remaining) - cardsDueThisMonth
    }

    /// `true` si no hay nada que desglosar.
    public var isEmpty: Bool {
        recurring.isEmpty && cards.isEmpty && justAfter.isEmpty
    }
}

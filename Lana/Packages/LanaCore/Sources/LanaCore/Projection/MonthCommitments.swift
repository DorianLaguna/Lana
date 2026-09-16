import Foundation

/// Lo que ya tiene dueño de aquí a fin de mes: los recurrentes que faltan por
/// registrarse y los cortes de tarjeta que vencen, contra el mes **calendario**
/// (ADR-0045, ADR-0046).
///
/// No reimplementa nada: arma un `PayPeriod` con el rango del mes y llama a
/// `commitments(from:registeredIn:asOf:)` y `cardCommitments(cards:ledger:asOf:)`,
/// que son las piezas ya probadas del disponible proyectado (ADR-0039). La
/// diferencia con `AvailableProjection` es el horizonte —el mes, no el periodo
/// de sueldo— y que aquí **solo cuentan las salidas**: un sueldo que todavía no
/// cae no es dinero que tengas (ADR-0008).
public struct MonthCommitments: Sendable, Equatable {
    /// De dónde sale el cálculo. Van juntos porque siempre se leen juntos, y
    /// porque quien llama ya los tiene cargados del mismo mes.
    public struct Inputs: Sendable {
        public let recurringItems: [RecurringItem]
        /// Los movimientos del mes, para no contar dos veces uno que ya se
        /// registró (`RecurringItem.registration(in:forMonthOf:)`).
        public let expenses: [Expense]
        public let cards: [Card]
        /// Con qué se calcula lo que falta de cada corte.
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

    /// La moneda de estos compromisos. Nunca se mezclan (Docs/CONVENTIONS.md).
    public let currency: Currency
    /// Los recurrentes que faltan en el mes, del más próximo al más lejano.
    public let recurring: [Commitment]
    /// Los cortes de tarjeta que vencen en lo que resta del mes.
    public let cards: [Commitment]
    /// Salidas que caen **justo después** del mes. Se muestran para que nadie
    /// se gaste la renta del 1 estando a día 28, pero no entran a la suma: el
    /// mes es el mes.
    public let justAfter: [Commitment]
    /// Lo que lleva acumulado cada tarjeta **después de su último corte**.
    ///
    /// **No se suma.** Todavía no se factura: se paga hasta el mes que entra y
    /// va a crecer mientras se siga usando la tarjeta. Por eso no tiene fecha
    /// límite — todavía no existe— y se muestra aparte de lo comprometido.
    public let accruing: [AccruingCharge]

    /// Lo acumulado en el ciclo abierto de una tarjeta. Sin fecha a propósito:
    /// su fecha de pago es la del corte que aún no cierra.
    public struct AccruingCharge: Sendable, Hashable, Identifiable {
        public var id: String {
            card
        }

        /// El alias de la tarjeta, como la nombró su dueño.
        public let card: String
        public let amount: Money

        public init(card: String, amount: Money) {
            self.card = card
            self.amount = amount
        }
    }

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
            return MonthCommitments(currency: currency, recurring: [], cards: [], justAfter: [], accruing: [])
        }
        let monthPeriod = PayPeriod(start: interval.start, end: interval.end, isAnchoredToIncome: false)
        let recurring = monthPeriod.commitments(
            from: inputs.recurringItems,
            registeredIn: inputs.expenses,
            asOf: asOf,
            calendar: calendar)
        let cardDues = monthPeriod.cardCommitments(
            cards: inputs.cards,
            ledger: inputs.ledger,
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
            cards: Self.outflows(cardDues, in: currency),
            justAfter: Self.outflows(after, in: currency),
            accruing: Self.accruing(in: inputs, currency: currency, asOf: asOf, calendar: calendar))
    }

    /// Lo que cada tarjeta de crédito lleva acumulado en su ciclo abierto.
    ///
    /// Es la misma cifra que el detalle de tarjeta llama "Después del corte",
    /// no una nueva: quien usa la tarjeta ve el mismo número en las dos
    /// pantallas.
    private static func accruing(
        in inputs: Inputs,
        currency: Currency,
        asOf: Date,
        calendar: Calendar) -> [AccruingCharge] {
        inputs.cards
            .compactMap { card -> AccruingCharge? in
                guard card.kind == .credit else { return nil }
                let amount = inputs.ledger.currentCycleBalance(for: card, asOf: asOf, calendar: calendar)
                guard amount.currency == currency, amount.amount > 0 else { return nil }
                return AccruingCharge(card: card.alias, amount: amount)
            }
            .sorted { first, second in
                first.amount.amount == second.amount.amount
                    ? first.card < second.card
                    : first.amount.amount > second.amount.amount
            }
    }

    /// Solo lo que sale, y solo en esta moneda. Un ingreso por venir se queda
    /// fuera a propósito: "Te queda" cuenta lo registrado, no lo prometido.
    private static func outflows(_ commitments: [Commitment], in currency: Currency) -> [Commitment] {
        commitments
            .filter { $0.amount.currency == currency && $0.amount.amount < 0 }
            .sorted { $0.date < $1.date }
    }

    /// Cuánto ya tiene dueño, en positivo.
    public var committed: Decimal {
        Self.sum(recurring) + Self.sum(cards)
    }

    /// Cuánto de eso es de tarjetas — el desglose las junta en un solo renglón,
    /// porque el detalle por tarjeta ya vive en "Esta quincena".
    public var cardsTotal: Decimal {
        Self.sum(cards)
    }

    /// Lo que de verdad queda libre después de lo comprometido. Puede ser
    /// negativo: lo que queda del mes no alcanza para lo que viene.
    public func free(after remaining: Decimal) -> Decimal {
        remaining - committed
    }

    /// `true` si no hay nada comprometido, asomándose ni acumulándose.
    public var isEmpty: Bool {
        recurring.isEmpty && cards.isEmpty && justAfter.isEmpty && accruing.isEmpty
    }

    private static func sum(_ commitments: [Commitment]) -> Decimal {
        commitments.reduce(Decimal(0)) { $0 + abs($1.amount.amount) }
    }
}

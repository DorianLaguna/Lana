import Foundation

/// Cuánto queda disponible en el periodo de pago vigente.
///
/// **De dónde sale el saldo:** no del banco —Lana no lo conoce— sino de lo que
/// el usuario registró: lo que entró menos lo que salió desde el último sueldo.
/// A eso se le suman los compromisos con fecha que faltan hasta el siguiente
/// (ADR-0008: solo lo que tiene fecha; las cuentas por cobrar nunca entran).
///
/// Eso hace la cifra **conservadora y dependiente del registro**: quien no
/// registró un gasto verá más de lo que tiene, y quien empezó a usar la app a
/// medio periodo verá menos. Por eso siempre viaja con `explanation`, que dice
/// de qué está hecha — la UI no debe mostrar el número sin esa línea.
public struct AvailableProjection: Sendable {
    public let period: PayPeriod
    public let currency: Currency
    /// Lo que entró en el periodo, ya registrado.
    public let received: Decimal
    /// Lo que salió en el periodo, ya registrado — la parte propia de un gasto
    /// compartido, no el total (ADR-0029).
    public let spent: Decimal
    /// Los compromisos con fecha que faltan, del más próximo al más lejano.
    public let upcoming: [Commitment]

    /// - Parameters:
    ///   - period: el periodo de pago vigente.
    ///   - currency: la moneda a proyectar. Nunca se cruzan dos.
    ///   - expenses: gastos e ingresos; se filtra lo que cae en el periodo.
    ///   - viewerIdentities: para contar solo la parte propia de un compartido.
    ///   - upcoming: los compromisos con fecha que aún no ocurren. Quien llama
    ///     los arma con `PayPeriod.commitments(from:)` y
    ///     `PayPeriod.cardCommitments(...)`.
    ///   - asOf: qué momento es "ahora", para saber qué ya ocurrió.
    public init(
        period: PayPeriod,
        currency: Currency,
        expenses: [Expense],
        viewerIdentities: [SharedListID: ParticipantID] = [:],
        upcoming: [Commitment],
        asOf: Date = Date()) {
        self.period = period
        self.currency = currency

        var received: Decimal = 0
        var spent: Decimal = 0
        for expense in expenses where period.contains(expense.date) {
            switch expense.kind {
            case .income:
                guard expense.amount.currency == currency else { continue }
                received += expense.amount.amount
            case .expense:
                let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
                guard personal.currency == currency else { continue }
                spent += personal.amount
            }
        }
        self.received = received
        self.spent = spent
        self.upcoming = upcoming
            .filter { $0.amount.currency == currency && $0.date > asOf && period.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    /// Lo que traes ahora mismo, según lo registrado en el periodo. Puede ser
    /// negativo: gastaste más de lo que te entró en estos días.
    public var balance: Money {
        Money(amount: received - spent, currency: currency)
    }

    /// Lo que quedaría al final del periodo, después de los compromisos que
    /// faltan. Reusa `Projection`, que es la pieza probada de esto (ADR-0008).
    public var available: Money {
        (try? Projection.available(
            currentBalance: balance,
            commitments: upcoming,
            through: period.through)) ?? balance
    }

    /// De qué está hecha la cifra, en una línea.
    ///
    /// Nunca se muestra el número sin esto: alguien que empezó a usar Lana hace
    /// una semana vería un disponible bajo y pensaría que su banco está mal.
    public var explanation: String {
        let base = period.isAnchoredToIncome
            ? "Va de tu último \(period.anchorName?.lowercased() ?? "ingreso") al siguiente"
            : "Va por quincena de calendario, porque no tienes un ingreso recurrente configurado"
        return "\(base). Sale de lo que registraste en Lana, no de tu banco."
    }
}

public extension PayPeriod {
    /// Los compromisos que faltan en el periodo, sacados de los recurrentes.
    ///
    /// Solo entran los que **todavía no se registraron en el mes de su
    /// ocurrencia** (`RecurringItem.registration(in:forMonthOf:calendar:)`):
    /// uno ya registrado ya es un movimiento real y contarlo otra vez lo
    /// cobraría dos veces. Un ingreso suma y un gasto resta, como pide
    /// `Commitment`.
    ///
    /// - Parameter expenses: los movimientos de los meses completos que toca
    ///   el periodo, no solo los del periodo — un sueldo adelantado el día 10
    ///   ya cubre la ocurrencia del 15 aunque caiga antes de que empiece.
    func commitments(
        from items: [RecurringItem],
        registeredIn expenses: [Expense],
        asOf date: Date,
        calendar: Calendar = .current) -> [Commitment] {
        items.compactMap { item in
            guard let occurrence = pendingOccurrence(of: item.dayOfMonth, after: date, calendar: calendar)
            else { return nil }
            guard item.registration(in: expenses, forMonthOf: occurrence, calendar: calendar) == nil else {
                return nil
            }
            let amount = item.kind == .income ? item.amount : -item.amount
            return Commitment(concept: item.name, amount: amount, date: occurrence)
        }
    }

    /// La próxima vez que cae `dayOfMonth` dentro de lo que resta del periodo.
    ///
    /// Mira el mes del inicio **y** el del final: un periodo anclado al sueldo
    /// puede cruzar de mes (del 30 de marzo al 15 de abril), y quedarse solo
    /// con el mes de hoy dejaría fuera todo lo que cae del otro lado — el pago
    /// de tarjeta del 10 de abril, por ejemplo.
    private func pendingOccurrence(of dayOfMonth: Int, after date: Date, calendar: Calendar) -> Date? {
        [start, end]
            .compactMap { Self.occurrence(of: dayOfMonth, inMonthOf: $0, calendar: calendar) }
            .filter { contains($0) && $0 > date }
            .min()
    }

    /// Los pagos de tarjeta que caen en lo que resta del periodo.
    ///
    /// El monto es lo que falta del último estado de cuenta
    /// (`outstandingStatementBalance`), la misma cifra que ya usa "Próximos
    /// pagos" y el botón de pagar — no una nueva inventada aquí.
    func cardCommitments(
        cards: [Card],
        ledger: CardLedger,
        asOf date: Date,
        calendar: Calendar = .current) -> [Commitment] {
        cards.compactMap { card in
            guard card.kind == .credit, let dueDay = card.dueDay else { return nil }
            guard let due = pendingOccurrence(of: dueDay, after: date, calendar: calendar) else { return nil }
            let amount = ledger.outstandingStatementBalance(for: card, asOf: date, calendar: calendar)
            guard amount.amount > 0 else { return nil }
            return Commitment(concept: card.alias, amount: -amount, date: due)
        }
    }
}

public extension PayPeriod {
    /// La misma aclaración que `AvailableProjection.explanation`, para cuando
    /// no hay ni una proyección que construir pero igual hay que explicar de
    /// dónde salen (o no salen) los números.
    var explanationFallback: String {
        isAnchoredToIncome
            ? "El periodo va de tu último \(anchorName?.lowercased() ?? "ingreso") al siguiente."
            : "Sin un ingreso recurrente configurado, el periodo va por quincena de calendario."
    }
}

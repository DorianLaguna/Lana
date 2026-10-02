import Foundation
import LanaCore

/// Lo gastado día por día en un mes y en el anterior, para "Día a día" en
/// Mes: qué días se gasta más y cómo va contra el mes pasado.
///
/// Va por **fecha de compra**, no por corte (ADR-0060): la pregunta es en qué
/// días se gastó. Por eso el acumulado no tiene que terminar en "Gastado".
///
/// **Los recurrentes van por corte**, como en "Gastado": lo que se pagará este
/// mes. Un Netflix cobrado a la tarjeta el 26 de septiembre, después del corte,
/// ya cuenta desde el día 1 de octubre; uno cobrado después del corte de
/// octubre se va a su propia serie, la del mes siguiente. La línea de gasto y
/// las barras siguen por fecha de compra: por eso el área de recurrentes puede
/// quedar arriba de la línea al empezar el mes.
public struct DailySpending: Equatable, Sendable {
    /// Un día del mes con su monto.
    public struct Point: Identifiable, Equatable, Sendable {
        public let day: Int
        public let amount: Decimal
        public var id: Int {
            day
        }
    }

    public let currency: Currency
    public let daysInMonth: Int
    public let previousDaysInMonth: Int
    /// Hasta qué día se dibuja este mes: hoy, o el último si ya pasó.
    public let lastDay: Int
    /// Lo gastado cada día de este mes, hasta `lastDay`.
    public let daily: [Point]
    /// Lo que se llevaba gastado al cierre de cada día, hasta `lastDay`.
    public let cumulative: [Point]
    /// Lo mismo del mes anterior, completo.
    public let previousCumulative: [Point]
    /// Lo recurrente que se paga este mes, por corte, hasta `lastDay`: lo del
    /// mes anterior que cerró en este corte entra el día 1, y lo de este mes
    /// en el día que se cobró. Vacío con el filtro "Sin recurrentes".
    public let recurringCumulative: [Point]
    /// Desde `lastDay` hasta fin de mes: lo de arriba más lo que falta por
    /// caer y se pagará este mes. Vacío en un mes que ya pasó.
    public let upcomingRecurringCumulative: [Point]
    /// Los recurrentes que faltan por caer y se pagan este mes, con su fecha.
    public let upcomingRecurring: [Commitment]
    /// Lo recurrente de este mes que ya le cuenta al siguiente porque se cobra
    /// a una tarjeta después de su corte, ya cobrado o por caer. Empieza el
    /// primer día que tiene algo.
    public let nextMonthRecurringCumulative: [Point]
    /// Los que faltan por caer y se pagarán el mes siguiente.
    public let upcomingNextMonthRecurring: [Commitment]

    /// El día que más se gastó; `nil` si no se gastó nada.
    public var peak: Point? {
        daily.filter { $0.amount > 0 }.max { $0.amount < $1.amount }
    }

    /// Lo que se llevaba al día `day`.
    public func spent(through day: Int) -> Decimal {
        cumulative.last { $0.day <= day }?.amount ?? 0
    }

    /// La parte recurrente de lo que se llevaba al día `day`, contando lo que
    /// falta por caer si `day` es a futuro.
    public func recurringSpent(through day: Int) -> Decimal {
        (recurringCumulative + upcomingRecurringCumulative).last { $0.day <= day }?.amount ?? 0
    }

    /// Lo que se llevaba el mes anterior al mismo día, recortado a su último
    /// día (el 31 de octubre se compara con el 30 de septiembre). `nil` si el
    /// mes anterior no tiene nada.
    public func previousSpent(through day: Int) -> Decimal? {
        guard previousCumulative.contains(where: { $0.amount > 0 }) else { return nil }
        let clamped = min(day, previousDaysInMonth)
        return previousCumulative.last { $0.day <= clamped }?.amount ?? 0
    }

    /// Qué mes se dibuja y cómo.
    struct Request {
        let month: Date
        let currency: Currency
        /// Hoy: este mes se dibuja hasta aquí.
        let asOf: Date
        /// Deja fuera lo ligado a un recurrente (ADR-0061): queda lo que se
        /// decidió gastar.
        let excludingRecurring: Bool
        /// Cómo se reparten los recurrentes por corte.
        var recurring = RecurringByCut()
    }

    /// Lo que hace falta para contar los recurrentes por corte.
    struct RecurringByCut {
        /// Lo recurrente del mes anterior que cerró en el corte de este.
        var carriedIn: Decimal = 0
        /// Si un cobro de este mes ya le cuenta al siguiente.
        var countsNextMonth: (Expense) -> Bool = { _ in false }
        /// Lo que falta por caer y se paga este mes.
        var upcomingThisMonth: [Commitment] = []
        /// Lo que falta por caer y ya se pagará el mes siguiente.
        var upcomingNextMonth: [Commitment] = []
    }

    /// - Parameters:
    ///   - current: los movimientos del mes, por fecha.
    ///   - previous: los del mes anterior, por fecha.
    ///   - amount: cuánto de cada movimiento es del usuario (su parte, si es
    ///     compartido).
    static func make(
        current: [Expense],
        previous: [Expense],
        request: Request,
        amount: (Expense) -> Decimal,
        calendar: Calendar) -> DailySpending? {
        let month = request.month
        let currency = request.currency
        let date = request.asOf
        let excludingRecurring = request.excludingRecurring
        guard let days = calendar.range(of: .day, in: .month, for: month)?.count,
              let previousMonth = calendar.date(byAdding: .month, value: -1, to: month),
              let previousDays = calendar.range(of: .day, in: .month, for: previousMonth)?.count else { return nil }
        let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let lastDay = isCurrentMonth ? calendar.component(.day, from: date) : days

        func byDay(_ items: [Expense], upTo limit: Int) -> [Decimal] {
            var totals = Array(repeating: Decimal(0), count: limit)
            for expense in items where expense.kind == .expense && expense.amount.currency == currency {
                if excludingRecurring, expense.recurringItemID != nil { continue }
                let day = calendar.component(.day, from: expense.date)
                guard day <= limit else { continue }
                totals[day - 1] += amount(expense)
            }
            return totals
        }

        let daily = byDay(current, upTo: lastDay)
        let recurring = excludingRecurring ? RecurringSeries() : recurringSeries(
            current,
            request: request,
            days: lastDay ... days,
            amount: amount,
            calendar: calendar)
        return DailySpending(
            currency: currency,
            daysInMonth: days,
            previousDaysInMonth: previousDays,
            lastDay: lastDay,
            daily: points(daily),
            cumulative: points(running(daily)),
            previousCumulative: points(running(byDay(previous, upTo: previousDays))),
            recurringCumulative: recurring.thisMonth,
            upcomingRecurringCumulative: recurring.upcoming,
            upcomingRecurring: recurring.upcomingItems,
            nextMonthRecurringCumulative: recurring.nextMonth,
            upcomingNextMonthRecurring: recurring.upcomingNextMonthItems)
    }

    static func points(_ values: [Decimal]) -> [Point] {
        values.enumerated().map { Point(day: $0.offset + 1, amount: $0.element) }
    }

    static func running(_ values: [Decimal]) -> [Decimal] {
        values.reduce(into: [Decimal]()) { $0.append(($0.last ?? 0) + $1) }
    }
}

// MARK: - Recurrentes por corte

extension DailySpending {
    struct RecurringSeries {
        var thisMonth: [Point] = []
        var upcoming: [Point] = []
        var upcomingItems: [Commitment] = []
        var nextMonth: [Point] = []
        var upcomingNextMonthItems: [Commitment] = []
    }

    /// - Parameter days: de `lastDay` (hoy, o el último del mes si ya pasó) al
    ///   último del mes.
    static func recurringSeries(
        _ current: [Expense],
        request: Request,
        days: ClosedRange<Int>,
        amount: (Expense) -> Decimal,
        calendar: Calendar) -> RecurringSeries {
        let lastDay = days.lowerBound
        let isCurrentMonth = calendar.isDate(request.asOf, equalTo: request.month, toGranularity: .month)
        let cut = request.recurring
        var thisMonth = Array(repeating: Decimal(0), count: lastDay)
        var nextMonth = Array(repeating: Decimal(0), count: days.upperBound)
        thisMonth[0] = cut.carriedIn
        for expense in current {
            guard expense.kind == .expense, expense.recurringItemID != nil,
                  expense.amount.currency == request.currency else { continue }
            let day = calendar.component(.day, from: expense.date)
            guard day <= lastDay else { continue }
            if cut.countsNextMonth(expense) {
                nextMonth[day - 1] += amount(expense)
            } else {
                thisMonth[day - 1] += amount(expense)
            }
        }
        func pending(_ items: [Commitment]) -> [Commitment] {
            guard isCurrentMonth else { return [] }
            return items.filter { $0.amount.currency == request.currency }.sorted { $0.date < $1.date }
        }
        let upcomingThisMonth = pending(cut.upcomingThisMonth)
        let upcomingNextMonth = pending(cut.upcomingNextMonth)
        for commitment in upcomingNextMonth {
            let day = max(calendar.component(.day, from: commitment.date), lastDay)
            nextMonth[min(day, days.upperBound) - 1] += abs(commitment.amount.amount)
        }
        let thisMonthRunning: [Decimal] = running(thisMonth)
        let start: Decimal = thisMonthRunning.last ?? 0
        let allNextMonth: [Point] = points(running(nextMonth))
        let nextMonthPoints: [Point] = allNextMonth.filter { point in
            nextMonth.prefix(point.day).contains { $0 > 0 }
        }
        var series = RecurringSeries()
        series.thisMonth = points(thisMonthRunning)
        series.upcoming = upcomingCumulative(upcomingThisMonth, from: start, days: days, calendar: calendar)
        series.upcomingItems = upcomingThisMonth
        series.nextMonth = nextMonthPoints
        series.upcomingNextMonthItems = upcomingNextMonth
        return series
    }
}

extension DailySpending {
    /// De hoy a fin de mes: lo recurrente ya cobrado más cada cobro que falta,
    /// en su día. Lo que debía caer antes de hoy y no se ha cobrado cae hoy.
    static func upcomingCumulative(
        _ upcoming: [Commitment],
        from start: Decimal,
        days: ClosedRange<Int>,
        calendar: Calendar) -> [Point] {
        guard !upcoming.isEmpty else { return [] }
        var total = start
        return days.map { day in
            total += upcoming
                .filter { max(calendar.component(.day, from: $0.date), days.lowerBound) == day }
                .reduce(Decimal(0)) { $0 + abs($1.amount.amount) }
            return Point(day: day, amount: total)
        }
    }
}

public extension DashboardModel {
    /// "Día a día" del mes que se ve, en la moneda principal.
    func dailySpending(excludingRecurring: Bool, asOf date: Date = Date()) -> DailySpending? {
        guard let currency = primaryCurrency else { return nil }
        return DailySpending.make(
            current: calendarExpenses,
            previous: previousCalendarExpenses,
            request: .init(
                month: month,
                currency: currency,
                asOf: date,
                excludingRecurring: excludingRecurring,
                recurring: recurringByCut(in: currency, asOf: date)),
            amount: { $0.personalAmount(viewerIdentities: viewerIdentities).amount },
            calendar: calendar)
    }

    /// Los recurrentes repartidos por corte (ADR-0060): lo del mes anterior
    /// que ya cuenta aquí, qué cobros de este mes se van al siguiente y cómo
    /// se reparte lo que falta por caer según la tarjeta con que se paga.
    private func recurringByCut(in currency: Currency, asOf date: Date) -> DailySpending.RecurringByCut {
        var carriedIn: Decimal = 0
        for expense in expenses where expense.date < month && expense.recurringItemID != nil {
            guard expense.kind == .expense, expense.amount.currency == currency else { continue }
            carriedIn += expense.personalAmount(viewerIdentities: viewerIdentities).amount
        }
        let pending = MonthCommitments.resolve(
            month: month,
            currency: currency,
            from: MonthCommitments.Inputs(
                recurringItems: recurringItems,
                expenses: calendarExpenses,
                cards: cards,
                ledger: cardLedger),
            asOf: date,
            calendar: calendar).recurring
        let deferred = pending.filter { commitment in
            // Un compromiso trae el nombre del recurrente, no el recurrente:
            // con qué se paga sale de ahí (`PayPeriod.commitments`).
            let item = recurringItems.first { $0.kind == .expense && $0.name == commitment.concept }
            let charge = Expense(
                kind: .expense,
                amount: Money(amount: abs(commitment.amount.amount), currency: commitment.amount.currency),
                concept: commitment.concept,
                date: commitment.date,
                paymentMethod: item?.paymentMethod)
            return countsNextMonth(charge)
        }
        let cards = cards
        let month = month
        let calendar = calendar
        return DailySpending.RecurringByCut(
            carriedIn: carriedIn,
            countsNextMonth: { Self.counts($0, after: month, cards: cards, calendar: calendar) },
            upcomingThisMonth: pending.filter { !deferred.contains($0) },
            upcomingNextMonth: deferred)
    }

    /// Si un cobro de este mes ya le cuenta al siguiente por el corte de su
    /// tarjeta: lo mismo que dice "Para noviembre" en la lista.
    private func countsNextMonth(_ expense: Expense) -> Bool {
        Self.counts(expense, after: month, cards: cards, calendar: calendar)
    }

    private static func counts(_ expense: Expense, after month: Date, cards: [Card], calendar: Calendar) -> Bool {
        guard let counted = BudgetMonth.month(of: expense, cards: cards, calendar: calendar) else { return false }
        return counted > month
    }

    /// Los gastos de un día del mes que se ve, el más reciente primero: lo que
    /// abre tocar ese día en "Día a día". Respeta el mismo filtro.
    func expenses(onDay day: Int, excludingRecurring: Bool) -> [Expense] {
        calendarExpenses
            .filter { expense in
                expense.kind == .expense
                    && calendar.component(.day, from: expense.date) == day
                    && !(excludingRecurring && expense.recurringItemID != nil)
            }
            .sorted { $0.date > $1.date }
    }

    /// Si hay algo ligado a un recurrente en este mes o el anterior: sin eso,
    /// el filtro "Sin recurrentes" no cambiaría nada y no se muestra.
    var hasRecurringSpending: Bool {
        recurringItems.contains { $0.kind == .expense }
            || (calendarExpenses + previousCalendarExpenses)
            .contains { $0.kind == .expense && $0.recurringItemID != nil }
    }
}

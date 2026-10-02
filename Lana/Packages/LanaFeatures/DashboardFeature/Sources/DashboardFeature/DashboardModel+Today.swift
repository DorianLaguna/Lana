import Foundation
import LanaCore

/// Cuánto toca gastar al día para llegar a fin de mes (Hoy, sección 3).
public enum DailyPace: Equatable, Sendable {
    /// Lo **libre** repartido entre los días que faltan, contando hoy — no lo
    /// restante a secas: repartir dinero que ya tiene dueño sería mentir
    /// (ADR-0046).
    case allowance(Money, untilDay: Int)
    /// Se gastó más de lo que entró; cuánto de más.
    case overspent(Money)
    /// Lo que queda del mes no alcanza para lo que ya tiene dueño, y falta
    /// tanto. No es lo mismo que haberse pasado: todavía no se gasta de más.
    case committed(short: Money)
}

/// Qué día del mes visible es hoy.
public struct DayProgress: Equatable, Sendable {
    public let day: Int
    public let daysInMonth: Int
}

/// Los movimientos que muestra Hoy: los de hoy o, si hoy no hubo, los del
/// último día con actividad.
public struct RecentDay: Sendable {
    public let day: Date
    public let isToday: Bool
    public let items: [Expense]
}

/// El subtítulo de una fila de movimiento.
public struct MovementSubtitle: Equatable, Sendable {
    /// "Despensa · Crédito Nu", "Ingreso · sueldo".
    public let text: String
    /// Se muestra apagado: la tarjeta con la que se pagó ya no existe.
    public let isMuted: Bool
}

// MARK: - Hoy y Mes

/// Los derivados de Hoy y Mes (rediseño, secciones 02 y 03). "Te queda" es
/// del mes, no el disponible proyectado (ADR-0045): lo pagado con crédito
/// cuenta en el mes de su corte y los sueldos por venir ya cuentan (ADR-0060).
public extension DashboardModel {
    /// Lo que dice "Te queda", por moneda: lo que le cuenta a este mes según
    /// su corte, contra lo que entró más los sueldos que faltan por caer
    /// (ADR-0060). Hoy y Mes muestran esta misma cifra.
    func budgetTotals(asOf date: Date = Date()) -> [PeriodTotal] {
        let incomeCurrencies = recurringItems.filter { $0.kind == .income }.map(\.amount.currency)
        let currencies = Set(statistics.currencies).union(incomeCurrencies)
            .sorted { $0.rawValue < $1.rawValue }
        return currencies.compactMap { currency in
            let registered = statistics.total(in: currency)
            let pending = expectedIncome(in: currency, asOf: date).reduce(Decimal(0)) { $0 + $1.amount.amount }
            guard registered != nil || pending > 0 else { return nil }
            return PeriodTotal(
                currency: currency,
                expenses: registered?.expenses ?? 0,
                income: (registered?.income ?? 0) + pending)
        }
    }

    /// "Para octubre": un movimiento de este mes que ya le cuenta al
    /// siguiente porque se compró con tarjeta después del corte (ADR-0060).
    /// `nil` para todo lo que cuenta en el mes que se ve.
    func deferredLabel(for expense: Expense) -> String? {
        guard let counted = BudgetMonth.month(of: expense, cards: cards, calendar: calendar),
              counted > month else { return nil }
        return "Para \(LanaDateFormat.monthNameLowercased(counted))"
    }

    /// Las notas bajo la cifra de Mes: los sueldos que ya cuenta y lo que
    /// movió el corte de las tarjetas.
    func monthTotalsNotes(in currency: Currency, asOf date: Date = Date()) -> [String] {
        [expectedIncomeNote(in: currency, asOf: date)].compactMap(\.self) + cutoffNotes(in: currency)
    }

    /// Lo que mueve el corte de las tarjetas respecto al calendario, dicho en
    /// Mes para que la lista no parezca incompleta (ADR-0060): lo comprado el
    /// mes anterior que cerró en este corte, y lo comprado este mes después
    /// del corte, que ya le cuenta al siguiente.
    func cutoffNotes(in currency: Currency) -> [String] {
        let monthStart = month
        let counted = Set(expenses.map(\.id))
        let carriedIn = personalSum(expenses.filter { $0.date < monthStart }, in: currency)
        let carriedOut = personalSum(
            calendarExpenses.filter { $0.kind == .expense && !counted.contains($0.id) },
            in: currency)
        var notes: [String] = []
        if carriedIn > 0, let previous = calendar.date(byAdding: .month, value: -1, to: monthStart) {
            let amount = MoneyDisplay.compact(Money(amount: carriedIn, currency: currency))
            let name = LanaDateFormat.monthNameLowercased(previous)
            notes.append("Incluye \(amount) de compras con tarjeta de \(name) que cerraron en el corte de este mes.")
        }
        if carriedOut > 0, let next = calendar.date(byAdding: .month, value: 1, to: monthStart) {
            let amount = MoneyDisplay.compact(Money(amount: carriedOut, currency: currency))
            let name = LanaDateFormat.monthNameLowercased(next)
            notes.append("\(amount) de compras con tarjeta después del corte ya cuentan en \(name).")
        }
        return notes
    }

    private func personalSum(_ items: [Expense], in currency: Currency) -> Decimal {
        items
            .filter { $0.kind == .expense && $0.amount.currency == currency }
            .reduce(Decimal(0)) { $0 + $1.personalAmount(viewerIdentities: viewerIdentities).amount }
    }

    /// Los sueldos que "Te queda" ya cuenta aunque todavía no caen.
    func expectedIncome(in currency: Currency, asOf date: Date = Date()) -> [Commitment] {
        MonthCommitments.expectedIncome(
            month: month,
            currency: currency,
            recurringItems: recurringItems,
            expenses: calendarExpenses,
            asOf: date,
            calendar: calendar)
    }

    /// "Incluye $24,000 que esperas el 14 y el 30.": sin esto, "Te queda"
    /// parecería dinero que ya está en la cuenta. `nil` si no se espera nada.
    func expectedIncomeNote(in currency: Currency, asOf date: Date = Date()) -> String? {
        let expected = expectedIncome(in: currency, asOf: date)
        guard !expected.isEmpty else { return nil }
        let sum = expected.reduce(Decimal(0)) { $0 + $1.amount.amount }
        let days = expected
            .map { "el \(calendar.component(.day, from: $0.date))" }
            .reduce(into: [String]()) {
                if !$0.contains($1) {
                    $0.append($1)
                }
            }
        let when = days.count > 1
            ? days.dropLast().joined(separator: ", ") + " y " + (days.last ?? "")
            : days.joined()
        return "Incluye \(MoneyDisplay.compact(Money(amount: sum, currency: currency))) que esperas \(when)."
    }

    /// `true` el último día del mes y en cualquier mes que ya pasó: ya no hay
    /// "te queda" que repartir, hay lo que se ahorró (ADR-0060).
    func isMonthClosing(asOf date: Date = Date()) -> Bool {
        guard let progress = dayProgress(asOf: date) else {
            return month < date
        }
        return progress.day == progress.daysInMonth
    }

    /// La moneda que manda en los bloques de una sola moneda (categorías,
    /// formas de pago). Con más de una, Hoy muestra un carrusel por moneda.
    var primaryCurrency: Currency? {
        statistics.currencies.first
    }

    /// Qué día del mes visible es `date`; `nil` si el mes visible es otro.
    func dayProgress(asOf date: Date = Date()) -> DayProgress? {
        guard calendar.isDate(date, equalTo: month, toGranularity: .month),
              let days = calendar.range(of: .day, in: .month, for: month) else { return nil }
        return DayProgress(day: calendar.component(.day, from: date), daysInMonth: days.count)
    }

    /// Lo libre del mes entre los días que faltan, contando hoy. `nil` sin
    /// ingreso (no hay contra qué comparar), fuera del mes en curso o en su
    /// último día: ahí ya no hay días que repartir (ADR-0060).
    ///
    /// - Parameter committed: lo que ya tiene dueño y no se puede repartir
    ///   (ADR-0046). En cero, es el ritmo de antes de ese ADR.
    func dailyPace(for total: PeriodTotal, committed: Decimal = 0, asOf date: Date = Date()) -> DailyPace? {
        guard total.income > 0, let progress = dayProgress(asOf: date),
              progress.day < progress.daysInMonth else { return nil }
        guard total.remaining >= 0 else {
            return .overspent(Money(amount: -total.remaining, currency: total.currency))
        }
        let free = total.remaining - committed
        guard free >= 0 else {
            return .committed(short: Money(amount: -free, currency: total.currency))
        }
        let daysLeft = max(progress.daysInMonth - progress.day + 1, 1)
        return .allowance(
            Money(amount: free / Decimal(daysLeft), currency: total.currency),
            untilDay: progress.daysInMonth)
    }

    /// Lo que ya tiene dueño de aquí a fin de mes, en la moneda de `total`
    /// (ADR-0046).
    ///
    /// Mirando un mes pasado sale vacío solo: los constructores de compromisos
    /// filtran por fecha posterior a `asOf`, así que agosto no tiene pendientes
    /// en septiembre. No hace falta un caso especial.
    func monthCommitments(for total: PeriodTotal, asOf date: Date = Date()) -> MonthCommitments {
        MonthCommitments.resolve(
            month: month,
            currency: total.currency,
            from: MonthCommitments.Inputs(
                recurringItems: recurringItems,
                expenses: calendarExpenses,
                cards: cards,
                ledger: cardLedger),
            asOf: date,
            calendar: calendar)
    }

    /// Los movimientos de hoy o, si no hubo, los del último día con actividad
    /// del mes visible. Como máximo `limit`.
    func recentMovements(asOf date: Date = Date(), limit: Int = 3) -> RecentDay? {
        let sections = calendarExpenses.groupedByDay(calendar: calendar)
        let pastOrToday = sections.filter { $0.day <= date }
        guard let latest = pastOrToday.max(by: { $0.day < $1.day }) ?? sections.first else { return nil }
        return RecentDay(
            day: latest.day,
            isToday: calendar.isDate(latest.day, inSameDayAs: date),
            items: Array(latest.items.prefix(limit)))
    }

    /// Los meses que ofrece el selector de Hoy, del actual hacia atrás.
    func selectableMonths(asOf date: Date = Date(), count: Int = 12) -> [Date] {
        guard let current = calendar.dateInterval(of: .month, for: date)?.start else { return [] }
        return (0 ..< count).compactMap { calendar.date(byAdding: .month, value: -$0, to: current) }
    }

    /// "Categoría · Forma de pago" para una fila de movimiento.
    func subtitle(for expense: Expense) -> MovementSubtitle {
        Self.subtitle(for: expense, cards: cards, cardsAreKnown: hasLoadedCards)
    }

    /// Las categorías de la moneda principal, de mayor a menor.
    var primaryCategoryTotals: [CategoryTotal] {
        primaryCurrency.map { statistics.categoryTotals(in: $0) } ?? []
    }

    /// Las formas de pago de la moneda principal, de mayor a menor.
    var primaryPaymentMethodTotals: [CategoryTotal] {
        primaryCurrency.map { statistics.paymentMethodTotals(in: $0) } ?? []
    }

    /// "68% crédito": la forma de pago que más pesa. `nil` sin gastos.
    var paymentMixSummary: String? {
        let totals = primaryPaymentMethodTotals
        let sum = totals.reduce(Decimal(0)) { $0 + $1.amount }
        guard let top = totals.first, sum > 0 else { return nil }
        return "\(Percentage.rounded(top.amount, of: sum))% \(top.category)"
    }

    /// "Ahorraste 21%". `nil` sin ingreso registrado.
    var savingsSummary: String? {
        guard let currency = primaryCurrency, let rate = statistics.savingsRate(in: currency) else { return nil }
        let percent = Percentage.rounded(rate, of: 1)
        return percent >= 0 ? "Ahorraste \(percent)%" : "Gastaste más de lo que entró"
    }

    /// Gasto sobre ingreso, para la barra. `nil` sin ingreso.
    static func spentFraction(of total: PeriodTotal) -> Double? {
        guard total.income > 0 else { return nil }
        return NSDecimalNumber(decimal: total.expenses / total.income).doubleValue
    }

    /// El nombre visible de una categoría de gasto.
    static func categoryDisplayName(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Sin categoría" }
        if let known = SuggestedCategory(rawValue: raw) {
            return known.displayName
        }
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    /// La regla del subtítulo, sin estado — para probarla sin store.
    static func subtitle(for expense: Expense, cards: [Card], cardsAreKnown: Bool = true) -> MovementSubtitle {
        let category = categoryLabel(for: expense)
        switch expense.paymentMethod {
        case nil:
            return MovementSubtitle(text: category, isMuted: false)
        case .cash:
            return MovementSubtitle(text: "\(category) · Efectivo", isMuted: false)
        case .transfer:
            return MovementSubtitle(text: "\(category) · Transferencia", isMuted: false)
        case let .credit(cardID):
            return cardSubtitle(
                category: category,
                kindName: "Crédito",
                cardID: cardID,
                cards: cards,
                cardsAreKnown: cardsAreKnown)
        case let .debit(cardID):
            return cardSubtitle(
                category: category,
                kindName: "Débito",
                cardID: cardID,
                cards: cards,
                cardsAreKnown: cardsAreKnown)
        }
    }

    private static func cardSubtitle(
        category: String,
        kindName: String,
        cardID: CardID,
        cards: [Card],
        cardsAreKnown: Bool) -> MovementSubtitle {
        if let card = cards.first(where: { $0.id == cardID }) {
            return MovementSubtitle(text: "\(category) · \(kindName) \(card.alias)", isMuted: false)
        }
        guard cardsAreKnown else {
            return MovementSubtitle(text: "\(category) · \(kindName)", isMuted: false)
        }
        return MovementSubtitle(text: "\(category) · Tarjeta eliminada", isMuted: true)
    }

    private static func categoryLabel(for expense: Expense) -> String {
        guard expense.kind == .income else { return categoryDisplayName(expense.category) }
        let detail = expense.subcategory ?? expense.category
            .flatMap { IncomeCategory(rawValue: $0)?.displayName.lowercased() }
        return detail.map { "Ingreso · \($0)" } ?? "Ingreso"
    }
}

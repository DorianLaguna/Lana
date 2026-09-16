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
/// del mes calendario, no el disponible proyectado (ADR-0045).
public extension DashboardModel {
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
    /// ingreso (no hay contra qué comparar) o fuera del mes en curso.
    ///
    /// - Parameter committed: lo que ya tiene dueño y no se puede repartir
    ///   (ADR-0046). En cero, es el ritmo de antes de ese ADR.
    func dailyPace(for total: PeriodTotal, committed: Decimal = 0, asOf date: Date = Date()) -> DailyPace? {
        guard total.income > 0, let progress = dayProgress(asOf: date) else { return nil }
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
                expenses: expenses,
                cards: cards,
                ledger: cardLedger),
            asOf: date,
            calendar: calendar)
    }

    /// Los movimientos de hoy o, si no hubo, los del último día con actividad
    /// del mes visible. Como máximo `limit`.
    func recentMovements(asOf date: Date = Date(), limit: Int = 3) -> RecentDay? {
        let sections = daySections
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
        return "\(Self.percent(top.amount, of: sum))% \(top.category)"
    }

    /// "Ahorraste 21%". `nil` sin ingreso registrado.
    var savingsSummary: String? {
        guard let currency = primaryCurrency, let rate = statistics.savingsRate(in: currency) else { return nil }
        let percent = Self.percent(rate, of: 1)
        return percent >= 0 ? "Ahorraste \(percent)%" : "Gastaste más de lo que entró"
    }

    /// El porcentaje entero de `part` sobre `whole`, redondeado.
    static func percent(_ part: Decimal, of whole: Decimal) -> Int {
        guard whole != 0 else { return 0 }
        var value = part / whole * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
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

import Foundation

/// Un punto de la serie anual: cuánto se gastó y cuánto entró en un mes, en
/// una moneda. La serie siempre trae los doce, incluso los vacíos, para que la
/// gráfica no se deforme al saltarse meses.
public struct MonthlyPoint: Identifiable, Sendable, Hashable {
    public var id: Date {
        month
    }

    /// El primer día del mes, a medianoche.
    public let month: Date
    public let currency: Currency
    public let expenses: Decimal
    public let income: Decimal
    /// `false` en un mes sin un solo movimiento. No es lo mismo que un mes en
    /// ceros: uno es "no gastaste", el otro es "no sabemos".
    public let hasActivity: Bool

    public init(month: Date, currency: Currency, expenses: Decimal, income: Decimal, hasActivity: Bool) {
        self.month = month
        self.currency = currency
        self.expenses = expenses
        self.income = income
        self.hasActivity = hasActivity
    }
}

/// Un grupo de "gastos hormiga": movimientos chicos y repetidos que por
/// separado no se notan y juntos sí pesan.
public struct AntExpenseGroup: Identifiable, Sendable, Hashable {
    public var id: String {
        label
    }

    /// La subcategoría, o la categoría si el gasto no traía subcategoría.
    public let label: String
    public let count: Int
    public let total: Decimal
    public let median: Decimal
    public let currency: Currency

    public init(label: String, count: Int, total: Decimal, median: Decimal, currency: Currency) {
        self.label = label
        self.count = count
        self.total = total
        self.median = median
        self.currency = currency
    }
}

/// Qué tan seguido hay movimientos registrados en el periodo.
///
/// - Important: se deriva de `Expense.date`, la fecha **del gasto**, no de
///   cuándo se capturó — el read model no guarda `recordedAt`. Por eso esto se
///   llama "días con movimiento" y no "racha de captura": un domingo que se
///   registró el lunes cuenta como domingo. La copy de la UI tiene que decir lo
///   mismo, o el número miente.
public struct CaptureConsistency: Sendable, Hashable {
    /// Días distintos con al menos un movimiento.
    public let daysWithActivity: Int
    /// Días del periodo ya transcurridos — el denominador honesto: en marzo no
    /// se compara contra los 365 del año.
    public let daysElapsed: Int
    /// La racha más larga de días seguidos con movimiento.
    public let longestStreak: Int
    /// La racha viva al día de hoy. Un día de hoy sin movimiento todavía no la
    /// rompe: el día no ha terminado (Lana no regaña).
    public let currentStreak: Int

    public init(daysWithActivity: Int, daysElapsed: Int, longestStreak: Int, currentStreak: Int) {
        self.daysWithActivity = daysWithActivity
        self.daysElapsed = daysElapsed
        self.longestStreak = longestStreak
        self.currentStreak = currentStreak
    }

    /// Qué fracción de los días transcurridos tuvo movimiento (`0.4` = 40%).
    /// `nil` si el periodo todavía no empieza.
    public var coverage: Decimal? {
        guard daysElapsed > 0 else { return nil }
        return Decimal(daysWithActivity) / Decimal(daysElapsed)
    }
}

/// Las estadísticas de un año completo: la serie de doce meses, los extremos,
/// el promedio, los gastos hormiga y la consistencia del registro.
///
/// Se le puede pasar un rango más ancho del año (la vista anual carga
/// veinticuatro meses de una sola vez para poder comparar contra el año
/// pasado): filtra por su cuenta lo que cae en `year`.
///
/// No persiste nada (ADR-0005) ni suma monedas distintas
/// (Docs/CONVENTIONS.md → Multi-moneda).
public struct AnnualStatistics: Sendable {
    /// El año que se está viendo.
    public let year: Int
    /// Las sumas del año completo: total, categorías, subcategorías, formas de
    /// pago y tasa de ahorro.
    public let period: PeriodStatistics

    private let calendar: Calendar
    private let referenceDate: Date
    private let yearExpenses: [Expense]
    private let viewerIdentities: [SharedListID: ParticipantID]
    private let monthStarts: [Date]
    private let statisticsByMonth: [Date: PeriodStatistics]
    private let minimumAntOccurrences: Int
    private let antThresholdFraction: Decimal

    /// - Parameters:
    ///   - year: el año a analizar. Lo que caiga fuera se ignora.
    ///   - expenses: gastos e ingresos, de cualquier rango. Se filtran aquí.
    ///   - viewerIdentities: qué participante es "yo" en cada lista compartida
    ///     (ADR-0022), para contar solo la parte propia de un gasto compartido.
    ///   - calendar: inyectable para que los tests no dependan de la zona
    ///     horaria de la máquina.
    ///   - referenceDate: qué día es "hoy". Decide cuántos meses del año ya
    ///     transcurrieron, y por lo tanto el denominador del promedio.
    ///   - minimumAntOccurrences: cuántas veces tiene que repetirse un
    ///     concepto para considerarse hormiga.
    ///   - antThresholdFraction: qué tan chico tiene que ser, como fracción
    ///     del gasto mensual promedio.
    public init(
        year: Int,
        expenses: [Expense],
        viewerIdentities: [SharedListID: ParticipantID] = [:],
        calendar: Calendar = .current,
        referenceDate: Date = Date(),
        minimumAntOccurrences: Int = 5,
        antThresholdFraction: Decimal = Decimal(string: "0.05") ?? 0) {
        self.year = year
        self.calendar = calendar
        self.referenceDate = referenceDate
        self.viewerIdentities = viewerIdentities
        self.minimumAntOccurrences = minimumAntOccurrences
        self.antThresholdFraction = antThresholdFraction

        let yearExpenses = expenses.filter { calendar.component(.year, from: $0.date) == year }
        self.yearExpenses = yearExpenses
        period = PeriodStatistics(expenses: yearExpenses, viewerIdentities: viewerIdentities)

        monthStarts = (1 ... 12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
        let grouped = Dictionary(grouping: yearExpenses) { expense in
            calendar.dateInterval(of: .month, for: expense.date)?.start ?? expense.date
        }
        statisticsByMonth = grouped.mapValues {
            PeriodStatistics(expenses: $0, viewerIdentities: viewerIdentities)
        }
    }

    /// Las monedas presentes en el año. Cada una se ve en su propio bloque.
    public var currencies: [Currency] {
        period.currencies
    }

    /// La serie de doce meses de una moneda, de enero a diciembre. Los meses
    /// sin movimiento vienen en cero con `hasActivity == false`.
    public func monthlyPoints(in currency: Currency) -> [MonthlyPoint] {
        monthStarts.map { month in
            let statistics = statisticsByMonth[month]
            let total = statistics?.total(in: currency)
            return MonthlyPoint(
                month: month,
                currency: currency,
                expenses: total?.expenses ?? 0,
                income: total?.income ?? 0,
                hasActivity: (statistics?.transactionCount ?? 0) > 0)
        }
    }

    /// Cuántos meses del año ya transcurrieron: 12 para un año pasado, el mes
    /// en curso para el año actual, 0 para uno que no ha empezado. Es el
    /// denominador del promedio — dividir marzo entre 12 daría un promedio
    /// falsamente bajo.
    public var monthsElapsed: Int {
        let currentYear = calendar.component(.year, from: referenceDate)
        if year < currentYear {
            return 12
        }
        if year > currentYear {
            return 0
        }
        return calendar.component(.month, from: referenceDate)
    }

    /// El gasto mensual promedio del año en una moneda, sobre los meses
    /// transcurridos. `nil` si el año todavía no empieza.
    public func monthlyAverage(in currency: Currency) -> Decimal? {
        guard monthsElapsed > 0 else { return nil }
        guard let expenses = period.total(in: currency)?.expenses else { return nil }
        return expenses / Decimal(monthsElapsed)
    }

    /// El mes más caro y el más barato del año en una moneda.
    ///
    /// Solo entran los meses **con movimiento**: un mes vacío no es "el más
    /// barato", es un mes del que no se sabe nada, y presentarlo como logro
    /// sería inventar. `nil` si no hay ni un mes con datos.
    public func extremes(in currency: Currency) -> (highest: MonthlyPoint, lowest: MonthlyPoint)? {
        let active = monthlyPoints(in: currency).filter(\.hasActivity)
        guard let highest = active.max(by: { $0.expenses < $1.expenses }),
              let lowest = active.min(by: { $0.expenses < $1.expenses })
        else { return nil }
        return (highest, lowest)
    }

    /// Los "gastos hormiga" del año en una moneda, de mayor a menor suma.
    ///
    /// Un grupo califica si se repitió al menos `minimumAntOccurrences` veces y
    /// su monto **mediano** es a lo mucho `antThresholdFraction` del gasto
    /// mensual promedio. La mediana y no el promedio: una sola compra grande
    /// entre muchas chicas no debería sacar al grupo de la lista.
    public func antExpenses(in currency: Currency) -> [AntExpenseGroup] {
        guard let average = monthlyAverage(in: currency), average > 0 else { return [] }
        let threshold = average * antThresholdFraction

        var amountsByLabel: [String: [Decimal]] = [:]
        for expense in yearExpenses where expense.kind == .expense {
            let personal = expense.personalAmount(viewerIdentities: viewerIdentities)
            guard personal.currency == currency, personal.amount > 0 else { continue }
            let subcategory = expense.subcategory.flatMap { $0.isEmpty ? nil : $0 }
            let label = subcategory ?? expense.category ?? "otro"
            amountsByLabel[label, default: []].append(personal.amount)
        }

        return amountsByLabel
            .compactMap { label, amounts -> AntExpenseGroup? in
                guard amounts.count >= minimumAntOccurrences else { return nil }
                let median = Self.median(of: amounts)
                guard median <= threshold else { return nil }
                return AntExpenseGroup(
                    label: label,
                    count: amounts.count,
                    total: amounts.reduce(0, +),
                    median: median,
                    currency: currency)
            }
            .sorted { first, second in
                first.total == second.total ? first.label < second.label : first.total > second.total
            }
    }

    /// Qué tan seguido hubo movimientos en el año, hasta hoy.
    public var captureConsistency: CaptureConsistency {
        guard let start = monthStarts.first,
              let yearInterval = calendar.dateInterval(of: .year, for: start)
        else { return CaptureConsistency(daysWithActivity: 0, daysElapsed: 0, longestStreak: 0, currentStreak: 0) }

        // El último día que cuenta: hoy si el año está en curso, el 31 de
        // diciembre si ya pasó, y nada si todavía no empieza.
        let lastDay = min(calendar.startOfDay(for: referenceDate), calendar.startOfDay(for: yearInterval.end - 1))
        let firstDay = calendar.startOfDay(for: yearInterval.start)
        guard lastDay >= firstDay else {
            return CaptureConsistency(daysWithActivity: 0, daysElapsed: 0, longestStreak: 0, currentStreak: 0)
        }

        let activeDays = Set(yearExpenses.map { calendar.startOfDay(for: $0.date) })
        let daysElapsed = (calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0) + 1

        var longest = 0
        var running = 0
        var day = firstDay
        while day <= lastDay {
            if activeDays.contains(day) {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return CaptureConsistency(
            daysWithActivity: activeDays.filter { $0 >= firstDay && $0 <= lastDay }.count,
            daysElapsed: daysElapsed,
            longestStreak: longest,
            currentStreak: currentStreak(activeDays: activeDays, lastDay: lastDay, firstDay: firstDay))
    }

    /// La racha viva, contando hacia atrás. Si el último día todavía no tiene
    /// movimiento se arranca desde el anterior: el día no ha terminado y darlo
    /// por perdido sería regañar por algo que aún puede pasar.
    private func currentStreak(activeDays: Set<Date>, lastDay: Date, firstDay: Date) -> Int {
        var day = activeDays.contains(lastDay)
            ? lastDay
            : calendar.date(byAdding: .day, value: -1, to: lastDay) ?? lastDay
        var streak = 0
        while day >= firstDay, activeDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private static func median(of amounts: [Decimal]) -> Decimal {
        let sorted = amounts.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

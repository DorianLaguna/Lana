import Foundation

/// Los cinco detectores, con el historial ya rebanado por mes.
///
/// Aparte de `Findings.swift` por tamaño (`swiftlint`). Cada detector devuelve
/// `nil` cuando no hay material suficiente: **es preferible no decir nada que
/// decir algo flojo** (Docs/CLAUDE.md → Tono: "si los datos no alcanzan para
/// decir algo con sustancia, di menos").
struct FindingContext {
    let input: Findings.Input
    let calendar: Calendar
    /// Primer día del mes que se analiza.
    let monthStart: Date
    /// Los gastos del mes, ya filtrados a la moneda y con la parte propia.
    let current: [DatedAmount]
    /// Los meses anteriores con actividad, del más reciente al más viejo.
    let previousMonths: [(start: Date, amounts: [DatedAmount])]

    /// Un gasto reducido a lo que los detectores necesitan.
    struct DatedAmount {
        let date: Date
        let amount: Decimal
        let concept: String
        let category: String
        let subcategory: String?
        let isFromKnownRecurringItem: Bool
    }

    init(input: Findings.Input, calendar: Calendar) {
        self.input = input
        self.calendar = calendar
        // En una local y no leyendo `monthStart` más abajo: leer una propiedad
        // dentro de una closure captura `self`, y Swift no lo permite mientras
        // queden propiedades sin inicializar.
        let start = calendar.dateInterval(of: .month, for: input.month)?.start ?? input.month
        monthStart = start

        var byMonth: [Date: [DatedAmount]] = [:]
        for expense in input.expenses where expense.kind == .expense {
            let personal = expense.personalAmount(viewerIdentities: input.viewerIdentities)
            guard personal.currency == input.currency, personal.amount > 0 else { continue }
            guard let start = calendar.dateInterval(of: .month, for: expense.date)?.start else { continue }
            byMonth[start, default: []].append(DatedAmount(
                date: expense.date,
                amount: personal.amount,
                concept: expense.concept,
                category: expense.category ?? "otro",
                subcategory: expense.subcategory.flatMap { $0.isEmpty ? nil : $0 },
                isFromKnownRecurringItem: expense.recurringItemID != nil))
        }

        current = byMonth[start] ?? []
        previousMonths = byMonth
            .filter { $0.key < start }
            .sorted { $0.key > $1.key }
            .map { (start: $0.key, amounts: $0.value) }
    }
}

// MARK: - Cómo vas

extension FindingContext {
    /// Lo gastado hasta hoy contra lo que llevabas el mismo día del mes pasado.
    ///
    /// Es el único hallazgo que mira el mes **a medias**: comparar un mes en
    /// curso contra uno completo diría siempre que vas mejor, que es una
    /// mentira cómoda.
    func pace() -> Finding? {
        guard calendar.isDate(input.asOf, equalTo: monthStart, toGranularity: .month) else { return nil }
        guard let previous = previousMonths.first else { return nil }
        let day = calendar.component(.day, from: input.asOf)

        let now = total(of: current, upToDayOfMonth: day)
        let then = total(of: previous.amounts, upToDayOfMonth: day)
        guard now > 0, then > 0 else { return nil }

        let difference = now - then
        guard difference != 0 else { return nil }
        let direction = difference > 0 ? "arriba" : "abajo"
        let sameDay = "\(day) de \(LanaDateFormat.monthNameLowercased(previous.start, calendar: calendar))"

        return Finding(
            kind: .pace,
            headline: "Vas \(money(abs(difference))) \(direction) de como ibas el \(sameDay)",
            detail: "Hasta hoy llevas \(money(now)); a estas alturas del mes pasado, \(money(then)).",
            magnitude: abs(difference),
            currency: input.currency)
    }

    private func total(of amounts: [DatedAmount], upToDayOfMonth day: Int) -> Decimal {
        amounts
            .filter { calendar.component(.day, from: $0.date) <= day }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
}

// MARK: - Cobros que se repiten

extension FindingContext {
    /// Conceptos que aparecen mes tras mes por un monto parecido y que **no**
    /// están dados de alta como recurrentes.
    ///
    /// Los que ya salieron de un recurrente se excluyen: proponer dar de alta
    /// algo que ya está dado de alta es ruido, no un hallazgo.
    func repeatedCharges() -> Finding? {
        var byConcept: [String: [DatedAmount]] = [:]
        for entry in ([current] + previousMonths.map(\.amounts)).flatMap(\.self)
            where !entry.isFromKnownRecurringItem {
            byConcept[LedgerToolbox.normalize(entry.concept), default: []].append(entry)
        }

        let repeated = byConcept.values.filter { Self.looksRecurring($0, calendar: calendar) }
        guard !repeated.isEmpty else { return nil }

        // Lo que costarían en un mes: el monto típico de cada uno, sumado.
        let monthly = repeated.reduce(Decimal(0)) { $0 + Self.typicalAmount($1) }
        guard monthly > 0 else { return nil }

        let names = repeated
            .compactMap { $0.first?.concept }
            .sorted()
            .prefix(4)
            .joined(separator: ", ")
        let count = repeated.count

        return Finding(
            kind: .repeatedCharges,
            headline: count == 1
                ? "Un cobro se repite cada mes: \(money(monthly))"
                : "\(count) cobros se repiten cada mes: \(money(monthly))",
            detail: "\(names). No están dados de alta como recurrentes.",
            magnitude: monthly,
            currency: input.currency)
    }

    /// Aparece en al menos tres meses distintos, una vez por mes, y el monto no
    /// se mueve más de 15%. Un café diario se repite mucho pero no es un cobro:
    /// por eso se pide **una por mes**, no muchas.
    private static func looksRecurring(_ entries: [DatedAmount], calendar: Calendar) -> Bool {
        let months = Set(entries.map { calendar.dateInterval(of: .month, for: $0.date)?.start ?? $0.date })
        guard months.count >= 3, entries.count == months.count else { return false }

        let amounts = entries.map(\.amount).sorted()
        guard let smallest = amounts.first, let largest = amounts.last, smallest > 0 else { return false }
        return (largest - smallest) / smallest <= Decimal(string: "0.15") ?? 0
    }

    /// El monto más reciente: si subió de precio, lo que importa es lo que
    /// cuesta ahora.
    private static func typicalAmount(_ entries: [DatedAmount]) -> Decimal {
        entries.max { $0.date < $1.date }?.amount ?? 0
    }
}

// MARK: - Desvío contra tu propio promedio

extension FindingContext {
    /// La categoría que más se salió de su propio promedio de los meses
    /// anteriores. Solo hacia arriba: "gastaste menos en despensa" no es algo
    /// sobre lo que nadie vaya a actuar.
    func categoryDeviation() -> Finding? {
        guard previousMonths.count >= 2 else { return nil }

        var averages: [String: Decimal] = [:]
        for month in previousMonths {
            for (category, amount) in Self.byCategory(month.amounts) {
                averages[category, default: 0] += amount
            }
        }
        let months = Decimal(previousMonths.count)
        averages = averages.mapValues { $0 / months }

        let now = Self.byCategory(current)
        let deviations = now.compactMap { category, amount -> CategoryDeviation? in
            guard let average = averages[category], average > 0 else { return nil }
            let difference = amount - average
            // Menos de un 20% arriba es ruido del mes, no un cambio de hábito.
            guard difference > 0, difference / average > Decimal(string: "0.2") ?? 0 else { return nil }
            return CategoryDeviation(category: category, difference: difference, average: average)
        }

        guard let top = deviations.max(by: { $0.difference < $1.difference }) else { return nil }
        return Finding(
            kind: .categoryDeviation,
            headline: "\(Self.capitalized(top.category)): \(money(top.difference)) arriba de tu promedio",
            detail: "Tu promedio de los últimos \(previousMonths.count) meses es \(money(top.average)).",
            magnitude: top.difference,
            currency: input.currency)
    }

    /// Una categoría que se salió de su propio promedio, con el promedio del
    /// que se salió — sin él, la cifra no se puede juzgar.
    private struct CategoryDeviation {
        let category: String
        let difference: Decimal
        let average: Decimal
    }

    private static func byCategory(_ amounts: [DatedAmount]) -> [String: Decimal] {
        var totals: [String: Decimal] = [:]
        for entry in amounts {
            totals[entry.category, default: 0] += entry.amount
        }
        return totals
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: - Fin de semana

extension FindingContext {
    /// Cuánto más pesa un día de fin de semana que uno entre semana.
    ///
    /// Se compara **por día**, no el total: hay cinco días entre semana y dos
    /// de fin, así que sumar y comparar diría siempre que entre semana se gasta
    /// más.
    func weekendWeight() -> Finding? {
        var weekendTotal = Decimal(0)
        var weekdayTotal = Decimal(0)
        var weekendDays: Set<Date> = []
        var weekdayDays: Set<Date> = []

        for entry in current {
            let day = calendar.startOfDay(for: entry.date)
            if calendar.isDateInWeekend(entry.date) {
                weekendTotal += entry.amount
                weekendDays.insert(day)
            } else {
                weekdayTotal += entry.amount
                weekdayDays.insert(day)
            }
        }

        guard weekendDays.count >= 2, weekdayDays.count >= 3 else { return nil }
        let perWeekend = weekendTotal / Decimal(weekendDays.count)
        let perWeekday = weekdayTotal / Decimal(weekdayDays.count)
        guard perWeekday > 0, perWeekend > perWeekday else { return nil }

        let percent = Findings.percent(perWeekend - perWeekday, of: perWeekday)
        // Menos de 20% no distingue un hábito del azar de un mes.
        guard percent >= 20 else { return nil }

        return Finding(
            kind: .weekend,
            headline: "Un día de fin de semana gastas \(percent)% más que uno entre semana",
            detail: "Sábados y domingos: \(money(perWeekend)) por día, contra \(money(perWeekday)).",
            magnitude: weekendTotal,
            currency: input.currency)
    }
}

// MARK: - Gasto hormiga

extension FindingContext {
    /// Lo chico que se repite y junto sí pesa, dentro del mes.
    ///
    /// Mismo criterio que `AnnualStatistics.antExpenses` —repeticiones mínimas
    /// y mediana por debajo de una fracción del gasto— pero acotado al periodo
    /// en vez de al año. Unificar ambos es el siguiente paso, con las pruebas
    /// de la vista anual como red.
    func antExpenses(minimumOccurrences: Int = 5) -> Finding? {
        let monthTotal = current.reduce(Decimal(0)) { $0 + $1.amount }
        guard monthTotal > 0 else { return nil }
        let threshold = monthTotal * (Decimal(string: "0.05") ?? 0)

        var byLabel: [String: [Decimal]] = [:]
        for entry in current {
            byLabel[entry.subcategory ?? entry.category, default: []].append(entry.amount)
        }

        let groups = byLabel.compactMap { label, amounts -> AntGroup? in
            guard amounts.count >= minimumOccurrences else { return nil }
            guard Self.median(of: amounts) <= threshold else { return nil }
            return AntGroup(label: label, count: amounts.count, total: amounts.reduce(0, +))
        }

        guard let top = groups.max(by: { $0.total < $1.total }) else { return nil }
        return Finding(
            kind: .antExpenses,
            // Mismo formato que la vista anual ("Café · 6 veces"): el conteo es
            // la mitad del dato, así que viaja junto a la etiqueta.
            headline: "\(Self.capitalized(top.label)) · \(top.count) veces: \(money(top.total))",
            detail: "Por separado casi no se notan.",
            magnitude: top.total,
            currency: input.currency)
    }

    /// Lo chico que se repite bajo una misma etiqueta. El conteo importa tanto
    /// como el total: "$1,080 en café" no dice lo mismo que "24 veces".
    private struct AntGroup {
        let label: String
        let count: Int
        let total: Decimal
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

// MARK: - Piezas compartidas

extension FindingContext {
    func money(_ amount: Decimal) -> String {
        Money(amount: amount, currency: input.currency).formatted()
    }
}

extension Findings {
    /// El porcentaje entero de `part` sobre `whole`, redondeado.
    static func percent(_ part: Decimal, of whole: Decimal) -> Int {
        guard whole != 0 else { return 0 }
        var value = part / whole * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}

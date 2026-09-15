import Foundation

/// Los cálculos deterministas que puede consultar una pregunta en lenguaje
/// natural (Docs/PLAN.md → Fase 9).
///
/// **Aquí está toda la aritmética.** El modelo elige cuál llamar y con qué
/// argumentos, y después narra lo que devolvió: nunca suma, nunca compara y
/// nunca ve el historial crudo (Docs/CLAUDE.md).
///
/// Cada método devuelve **texto ya formateado**, no números. Es a propósito, y
/// es la misma frontera que `PeriodFacts`: si el modelo recibiera un `Decimal`
/// alguien terminaría pidiéndole que lo opere.
///
/// Vive en `LanaCore` para poder probarse sin simulador. El envoltorio que la
/// convierte en `Tool` de `FoundationModels` vive en `LanaInsights`.
public struct LedgerToolbox: Sendable {
    // `internal` y no `private`: las herramientas de deuda viven en
    // `LedgerToolboxDebts.swift` —la misma struct, en otro archivo— y `private`
    // no cruza de archivo. Siguen sin salir de `LanaCore`.
    let store: any ExpenseStore
    let sharedListStore: any SharedListStore
    let cardStore: any CardStore
    let cardPaymentStore: any CardPaymentStore
    let recurringItemStore: (any RecurringItemStore)?
    let calendar: Calendar

    /// - Parameter recurringItemStore: de dónde salen el sueldo y los pagos
    ///   fijos. `nil` deja fuera `disponibleProyectado`, que sin ellos no tiene
    ///   con qué anclar el periodo ni qué compromisos contar.
    public init(
        store: any ExpenseStore,
        sharedListStore: any SharedListStore,
        cardStore: any CardStore,
        cardPaymentStore: any CardPaymentStore,
        recurringItemStore: (any RecurringItemStore)? = nil,
        calendar: Calendar = .current) {
        self.store = store
        self.sharedListStore = sharedListStore
        self.cardStore = cardStore
        self.cardPaymentStore = cardPaymentStore
        self.recurringItemStore = recurringItemStore
        self.calendar = calendar
    }

    /// El catálogo, para poder decirle al usuario qué se puede preguntar sin
    /// que lo tenga que adivinar.
    public static let catalog: [LedgerTool] = [
        LedgerTool(
            name: "totalPorCategoria",
            toolDescription: "Cuánto se gastó en un mes, desglosado por categoría."),
        LedgerTool(
            name: "comparaMeses",
            toolDescription: "Compara el gasto de dos meses y dice qué categorías subieron o bajaron."),
        LedgerTool(
            name: "mayoresGastos",
            toolDescription: "Los movimientos más grandes de un mes."),
        LedgerTool(
            name: "saldoDeLista",
            toolDescription: "Quién le debe a quién en una lista compartida."),
        LedgerTool(
            name: "deudaPorTarjeta",
            toolDescription: "Cuánto se debe en cada tarjeta de crédito."),
        LedgerTool(
            name: "origenDelIngreso",
            toolDescription: "De dónde vino el dinero en un mes, por categoría."),
        LedgerTool(
            name: "disponibleProyectado",
            toolDescription: "Cuánto queda del sueldo actual, después de los pagos con fecha que faltan.")
    ]

    // MARK: - Gasto

    /// Cuánto se gastó en un mes, por categoría y por moneda.
    public func totalPorCategoria(year: Int, month: Int) async -> String {
        guard let statistics = await statistics(year: year, month: month) else {
            return Self.invalidMonth
        }
        guard !statistics.currencies.isEmpty else {
            return "No hay movimientos registrados en \(Self.label(year: year, month: month))."
        }
        return statistics.currencies.map { currency in
            let total = statistics.total(in: currency)?.expenses ?? 0
            let breakdown = statistics.categoryTotals(in: currency)
                .map { "  \($0.category): \(Money(amount: $0.amount, currency: currency).formatted())" }
                .joined(separator: "\n")
            return """
            \(Self.label(year: year, month: month)), en \(currency.rawValue): \
            \(Money(amount: total, currency: currency).formatted()) en total.
            \(breakdown)
            """
        }.joined(separator: "\n\n")
    }

    /// Compara el gasto de dos meses, con las categorías que más se movieron.
    public func comparaMeses(
        yearA: Int, monthA: Int,
        yearB: Int, monthB: Int) async -> String {
        guard let current = await statistics(year: yearA, month: monthA),
              let previous = await statistics(year: yearB, month: monthB)
        else { return Self.invalidMonth }

        let comparison = PeriodComparison(current: current, previous: previous)
        guard !comparison.currencies.isEmpty else {
            return "No hay movimientos en ninguno de los dos meses."
        }

        return comparison.currencies.compactMap { currency -> String? in
            guard let delta = comparison.expenseDelta(in: currency) else { return nil }
            let movements = comparison.categoryDeltas(in: currency)
                .prefix(4)
                .filter { $0.delta.absolute != 0 }
                .map { entry in
                    let amount = Money(amount: abs(entry.delta.absolute), currency: currency).formatted()
                    let direction = entry.delta.direction == .up ? "subió" : "bajó"
                    return "  \(entry.category): \(direction) \(amount)"
                }
                .joined(separator: "\n")
            return """
            En \(currency.rawValue), \(Self.label(year: yearA, month: monthA)) \
            \(Self.describe(delta)) contra \(Self.label(year: yearB, month: monthB)).
            \(movements)
            """
        }.joined(separator: "\n\n")
    }

    /// Los movimientos más grandes de un mes.
    public func mayoresGastos(year: Int, month: Int, limit: Int = 5) async -> String {
        guard let range = range(year: year, month: month) else { return Self.invalidMonth }
        guard let expenses = try? await store.expenses(in: range) else {
            return "No se pudieron leer los movimientos."
        }
        let identities = await sharedListStore.viewerIdentities(for: expenses)
        let top = expenses
            .filter { $0.kind == .expense }
            .map { ($0, $0.personalAmount(viewerIdentities: identities)) }
            // Ordena por monto dentro de cada moneda; comparar `Money` de
            // monedas distintas revienta por `precondition`, así que se compara
            // el `Decimal` y la moneda se dice en cada renglón.
            .sorted { $0.1.amount > $1.1.amount }
            .prefix(max(1, min(limit, 10)))

        guard !top.isEmpty else {
            return "No hay gastos registrados en \(Self.label(year: year, month: month))."
        }
        let lines = top.map { expense, personal in
            "  \(expense.concept): \(personal.formatted())"
        }.joined(separator: "\n")
        return """
        Los gastos más grandes de \(Self.label(year: year, month: month)):
        \(lines)
        """
    }

    /// De dónde vino el dinero en un mes, por categoría (ADR-0040).
    ///
    /// Va aparte de `totalPorCategoria` porque los ingresos usan su propio
    /// catálogo: preguntar "¿en qué gasté?" y "¿de dónde me entró?" son dos
    /// preguntas distintas y no se contestan con la misma lista.
    public func origenDelIngreso(year: Int, month: Int) async -> String {
        guard let statistics = await statistics(year: year, month: month) else {
            return Self.invalidMonth
        }
        let label = Self.label(year: year, month: month)
        let blocks = statistics.currencies.compactMap { currency -> String? in
            let totals = statistics.incomeCategoryTotals(in: currency)
            guard !totals.isEmpty else { return nil }
            let breakdown = totals
                .map { "  \($0.category): \(Money(amount: $0.amount, currency: currency).formatted())" }
                .joined(separator: "\n")
            let total = statistics.total(in: currency)?.income ?? 0
            return """
            \(label), en \(currency.rawValue): entraron \
            \(Money(amount: total, currency: currency).formatted()).
            \(breakdown)
            """
        }
        guard !blocks.isEmpty else {
            return "No hay ingresos registrados en \(label)."
        }
        return blocks.joined(separator: "\n\n")
    }

    // MARK: - Piezas internas

    private func statistics(year: Int, month: Int) async -> PeriodStatistics? {
        guard let range = range(year: year, month: month) else { return nil }
        guard let expenses = try? await store.expenses(in: range) else { return nil }
        let identities = await sharedListStore.viewerIdentities(for: expenses)
        return PeriodStatistics(expenses: expenses, viewerIdentities: identities)
    }

    /// El rango del mes, con el mismo ajuste de `-1` segundo que el Dashboard.
    /// `nil` si el mes no existe — el modelo puede pedir el mes 13.
    private func range(year: Int, month: Int) -> DateInterval? {
        guard (1 ... 12).contains(month), (1900 ... 2200).contains(year) else { return nil }
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let interval = calendar.dateInterval(of: .month, for: start)
        else { return nil }
        return DateInterval(start: interval.start, end: interval.end.addingTimeInterval(-1))
    }

    static let invalidMonth = "Ese mes no existe."

    /// Solo el día y el mes: el año ya se entiende por el contexto.
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide))
    }

    private static func label(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            return "\(month)/\(year)"
        }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private static func describe(_ delta: PeriodDelta) -> String {
        let amount = Money(amount: abs(delta.absolute), currency: delta.currency).formatted()
        switch delta.direction {
        case .up: return "subió \(amount)"
        case .down: return "bajó \(amount)"
        case .unchanged: return "quedó igual"
        }
    }

    /// Sin acentos ni mayúsculas, para emparejar el nombre de una lista con lo
    /// que el usuario dictó.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

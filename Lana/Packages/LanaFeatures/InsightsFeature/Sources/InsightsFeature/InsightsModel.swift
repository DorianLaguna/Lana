import Foundation
import LanaCore
import Observation

/// Qué periodo está analizando la pantalla.
public enum InsightsPeriod: String, Sendable, Hashable, CaseIterable, Identifiable {
    case month
    case year

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .month: "Mes"
        case .year: "Año"
        }
    }
}

/// Toda la lógica del Análisis con IA: la mezcla del presupuesto contra la
/// regla que el usuario eligió, el resumen narrado, los patrones y las
/// sugerencias. La vista no decide nada (Docs/ARCHITECTURE.md).
///
/// El reparto de responsabilidades no se negocia: **el modelo etiqueta y
/// redacta, este modelo y `LanaCore` calculan.** Ver `SpendingClassifying` y
/// `InsightNarrating`.
@MainActor
@Observable
public final class InsightsModel {
    /// El periodo que se está viendo.
    public internal(set) var period: InsightsPeriod = .month
    /// Qué mes o qué año se está analizando. Arranca en hoy y se navega con
    /// `goToPrevious()`/`goToNext()` — antes el análisis solo sabía ver el mes
    /// en curso, que es justo lo que no sirve para entender un mes ya cerrado.
    public internal(set) var anchor: Date
    /// Si el modelo del sistema está disponible. Mientras no sea `.available`,
    /// la pantalla muestra la explicación y no analiza nada.
    public private(set) var availability: ParsingAvailability = .unknown
    /// `true` mientras se clasifica o se redacta.
    public private(set) var isLoading = false
    /// El último error, si algo falló.
    public private(set) var errorMessage: String?
    /// Lo de abajo es `internal(set)` y no `private(set)`: lo escribe
    /// `InsightsModelCache.swift` —la misma clase, en otro archivo— al aplicar
    /// lo ya analizado. Fuera del módulo siguen siendo de solo lectura.
    /// La mezcla del periodo, ya calculada por `LanaCore`.
    public internal(set) var mix: BudgetMix?
    /// Lo que el modelo escribió sobre el periodo.
    public internal(set) var narrative: PeriodNarrative?
    /// La regla que Lana propone, si hay material y el usuario no eligió ni
    /// descartó ya.
    public internal(set) var suggestion: BudgetRuleRecommendation?
    /// La moneda que está analizando. Con varias, se analiza la de más
    /// movimiento y la vista lo dice — nunca se cruzan
    /// (Docs/CONVENTIONS.md → Multi-moneda).
    public internal(set) var analyzedCurrency: Currency?
    /// Las demás monedas del periodo, si las hay — para poder avisar que este
    /// análisis no habla de ellas.
    public internal(set) var otherCurrencies: [Currency] = []
    /// Lo que el usuario está escribiendo para preguntar.
    public var question = ""
    /// La última respuesta, ya narrada. `nil` si todavía no ha preguntado.
    public private(set) var answer: String?
    /// `true` mientras se contesta una pregunta.
    public private(set) var isAnswering = false

    /// Lo ya analizado en esta sesión de la pantalla — ver
    /// `InsightsModel+Cache.swift`.
    var cache: [AnalysisKey: Analysis] = [:]

    private let store: any ExpenseStore
    private let sharedListStore: any SharedListStore
    private let classifier: any SpendingClassifying
    private let narrator: any InsightNarrating
    private let querying: any InsightQuerying
    private var preference: BudgetRulePreference
    let calendar: Calendar

    /// - Parameters:
    ///   - store: de dónde se leen las transacciones del periodo.
    ///   - sharedListStore: de dónde se lee qué participante es "yo", para
    ///     contar solo la parte propia de un gasto compartido (ADR-0022).
    ///   - classifier: quien etiqueta los tipos de gasto. Solo ve vocabulario.
    ///   - narrator: quien redacta, a partir de cifras ya calculadas.
    ///   - querying: quien contesta preguntas en lenguaje natural, llamando a
    ///     cálculos deterministas (`LedgerToolbox`).
    ///   - preference: dónde vive la regla que eligió el usuario.
    ///   - referenceDate: en qué mes abre el análisis. Por defecto, hoy; de
    ///     ahí el usuario navega a donde quiera.
    public init(
        store: any ExpenseStore,
        sharedListStore: any SharedListStore,
        classifier: any SpendingClassifying,
        narrator: any InsightNarrating,
        querying: any InsightQuerying = InMemoryInsightQuerying(),
        preference: BudgetRulePreference = BudgetRulePreference(),
        referenceDate: Date = Date(),
        calendar: Calendar = .current) {
        self.store = store
        self.sharedListStore = sharedListStore
        self.classifier = classifier
        self.narrator = narrator
        self.querying = querying
        self.preference = preference
        self.calendar = calendar
        anchor = referenceDate
    }

    /// La regla que el usuario eligió, o `nil` si todavía no elige ninguna.
    public var selectedRule: BudgetRule? {
        preference.rule
    }

    /// Cómo quedó repartido el periodo contra la regla vigente.
    public var shares: [BudgetShare] {
        mix?.shares(against: selectedRule) ?? []
    }

    /// Elige una regla.
    ///
    /// Persiste al instante y **no vuelve a llamar al modelo**: las cuatro
    /// reglas usan los mismos tres grupos, así que cambiar de regla solo
    /// cambia las metas. Por eso el cambio se ve sin spinner.
    public func selectRule(_ rule: BudgetRule?) {
        preference.setRule(rule)
        if rule != nil {
            suggestion = nil
            forgetSuggestions()
        }
    }

    /// Descarta la regla sugerida. Se recuerda: proponer lo mismo cada vez que
    /// se abre la pantalla es regañar con otro nombre.
    public func dismissSuggestion() {
        preference.dismissSuggestion()
        suggestion = nil
        forgetSuggestions()
    }

    /// Cambia de mes a año o al revés y vuelve a analizar.
    public func select(_ period: InsightsPeriod) async {
        guard period != self.period else { return }
        self.period = period
        await load()
    }

    /// El mes (o el año) anterior.
    public func goToPrevious() async {
        await move(by: -1)
    }

    /// El mes (o el año) siguiente.
    public func goToNext() async {
        await move(by: 1)
    }

    /// El periodo que el usuario tiene en pantalla, para que una pregunta sin
    /// periodo explícito se conteste sobre él y no sobre el mes de hoy.
    private var queryPeriod: QueryPeriod {
        QueryPeriod(
            year: calendar.component(.year, from: anchor),
            month: period == .month ? calendar.component(.month, from: anchor) : nil)
    }

    /// Cómo se llama el periodo que se está viendo: "septiembre de 2026", "2026".
    public var anchorLabel: String {
        switch period {
        case .month: anchor.formatted(.dateTime.month(.wide).year())
        case .year: anchor.formatted(.dateTime.year())
        }
    }

    /// El año que se está analizando — lo pide el selector de año.
    public var anchorYear: Int {
        calendar.component(.year, from: anchor)
    }

    private func move(by amount: Int) async {
        let component: Calendar.Component = period == .month ? .month : .year
        guard let moved = calendar.date(byAdding: component, value: amount, to: anchor) else { return }
        anchor = moved
        await load()
    }

    /// Consulta la disponibilidad del modelo y analiza el periodo vigente. Se
    /// llama cuando la pantalla aparece.
    public func onAppear() async {
        await load()
    }

    /// Tira lo analizado. Se llama al cerrar la pantalla: la próxima vez que se
    /// abra, los movimientos pueden ser otros y hay que volver a leerlos.
    public func onDismiss() {
        cache.removeAll()
        question = ""
        answer = nil
    }

    /// Preguntas para el estado vacío (Docs/PLAN.md → Fase 9).
    ///
    /// Fijas y no generadas: son el catálogo de lo que las herramientas
    /// deterministas sí pueden contestar (`LedgerToolbox.catalog`). Sugerir una
    /// pregunta que después no se puede responder es peor que no sugerir nada.
    public let suggestedQuestions = [
        "¿Cuánto me queda de esta quincena?",
        "¿En qué se me fue el dinero este mes?",
        "¿Gasté más que el mes pasado?",
        "¿Cuáles fueron mis gastos más grandes?",
        "¿De dónde me vino el dinero?",
        "¿Cuánto debo en mis tarjetas?"
    ]

    /// Contesta lo que el usuario escribió.
    ///
    /// El modelo no recibe los movimientos: elige qué cálculo determinista
    /// correr y narra el resultado (`LedgerToolbox`, Docs/CLAUDE.md).
    public func ask() async {
        let clean = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isAnswering else { return }
        isAnswering = true
        answer = nil
        errorMessage = nil
        defer { isAnswering = false }
        do {
            // La pregunta viaja con el periodo que el usuario tiene enfrente:
            // "¿cuáles fueron mis gastos más grandes?" mirando agosto se
            // contestaba sobre septiembre, porque la pregunta no nombra el mes
            // —ya se está viendo— y el modelo solo tenía la fecha de hoy.
            answer = try await querying.answer(clean, viewing: queryPeriod)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Borra la pregunta y su respuesta, sin tocar el análisis ni lo ya
    /// recordado de otros periodos.
    ///
    /// Es distinto de `onDismiss()`, que tira toda la caché: aquí solo se
    /// limpia la conversación para volver a preguntar en blanco.
    public func clearQuestion() {
        question = ""
        answer = nil
        errorMessage = nil
    }

    /// Pregunta una de las sugeridas, sin que el usuario tenga que teclearla.
    public func ask(_ suggested: String) async {
        question = suggested
        await ask()
    }

    private func load() async {
        availability = await classifier.availability
        guard availability == .available else { return }

        // Ya analizado en esta sesión: se muestra tal cual, sin spinner y sin
        // volver a molestar al modelo.
        let key = currentKey
        if let cached = cache[key] {
            errorMessage = nil
            apply(cached)
            return
        }

        guard let range = range(for: period) else { return }

        isLoading = true
        errorMessage = nil
        // Se limpia lo del periodo anterior antes de empezar: si la carga
        // falla a medias, mostrar las cifras de marzo bajo el encabezado de
        // abril sería peor que no mostrar nada.
        mix = nil
        narrative = nil
        suggestion = nil
        defer { isLoading = false }

        do {
            let expenses = try await store.expenses(in: range)
            let identities = await sharedListStore.viewerIdentities(for: expenses)
            let statistics = PeriodStatistics(expenses: expenses, viewerIdentities: identities)

            guard let currency = Self.primaryCurrency(of: statistics) else {
                // Un periodo sin movimientos también se recuerda: volver a él
                // no tiene por qué releer el store para decir lo mismo.
                cache[key] = Analysis(
                    mix: nil,
                    narrative: nil,
                    suggestion: nil,
                    analyzedCurrency: nil,
                    otherCurrencies: [])
                return
            }
            analyzedCurrency = currency
            otherCurrencies = statistics.currencies.filter { $0 != currency }

            // El modelo solo ve etiquetas: ni un monto, ni una fecha, ni un
            // concepto (`SpendingClassifying`).
            let groups = try await classifier.classify(BudgetMix.labels(in: expenses))
            let mix = BudgetMix(
                expenses: expenses,
                groupsByLabel: groups,
                viewerIdentities: identities,
                currency: currency,
                calendar: calendar)
            self.mix = mix

            // Las cifras llegan ya calculadas y ya formateadas.
            narrative = try await narrator.narrate(facts(statistics: statistics, mix: mix, currency: currency))
            await loadSuggestion(for: mix)
            cache[key] = Analysis(
                mix: mix,
                narrative: narrative,
                suggestion: suggestion,
                analyzedCurrency: currency,
                otherCurrencies: otherCurrencies)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSuggestion(for mix: BudgetMix) async {
        // Tres guardas, todas del código y ninguna del modelo: que haya
        // material suficiente, que el usuario no haya elegido ya, y que no
        // haya descartado la propuesta antes.
        guard mix.isEnoughForRecommendation,
              preference.rule == nil,
              !preference.hasDismissedSuggestion
        else {
            suggestion = nil
            return
        }
        // Que falle la sugerencia no puede tumbar el análisis: es lo accesorio
        // de la pantalla.
        suggestion = try? await narrator.recommendRule(
            mix: Self.mixLines(mix.shares(against: nil)),
            from: BudgetRule.allCases)
    }

    /// La moneda de más gasto. Con una sola —el caso normal— es esa; con
    /// varias, se analiza la principal y la vista avisa cuáles quedaron fuera.
    private static func primaryCurrency(of statistics: PeriodStatistics) -> Currency? {
        statistics.totals
            .max { ($0.expenses, $0.currency.rawValue) < ($1.expenses, $1.currency.rawValue) }?
            .currency
    }

    private func range(for period: InsightsPeriod) -> DateInterval? {
        let component: Calendar.Component = period == .month ? .month : .year
        guard let interval = calendar.dateInterval(of: component, for: anchor) else { return nil }
        // Mismo ajuste de -1 segundo que el Dashboard: `DateInterval.contains`
        // incluye los dos extremos.
        return DateInterval(start: interval.start, end: interval.end.addingTimeInterval(-1))
    }

    private func facts(statistics: PeriodStatistics, mix: BudgetMix, currency: Currency) -> PeriodFacts {
        let total = statistics.total(in: currency)
        return PeriodFacts(
            periodLabel: periodLabel,
            currencyCode: currency.rawValue,
            totalSpent: Money(amount: total?.expenses ?? 0, currency: currency).formatted(),
            totalIncome: (total?.income ?? 0) > 0
                ? Money(amount: total?.income ?? 0, currency: currency).formatted()
                : nil,
            savingsRate: statistics.savingsRate(in: currency)?
                .formatted(.percent.precision(.fractionLength(0))),
            topCategories: Self.lines(statistics.categoryTotals(in: currency).prefix(5)),
            topSubcategories: Self.lines(statistics.subcategoryTotals(in: currency).prefix(5)),
            paymentMethods: Self.lines(statistics.paymentMethodTotals(in: currency)),
            budgetMix: Self.mixLines(mix.shares(against: selectedRule)))
    }

    private var periodLabel: String {
        anchorLabel
    }

    private static func lines(_ totals: some Sequence<CategoryTotal>) -> [String] {
        totals.map { "\($0.category): \(Money(amount: $0.amount, currency: $0.currency).formatted())" }
    }

    private static func mixLines(_ shares: [BudgetShare]) -> [String] {
        shares.map { share in
            "\(share.group.displayName): \(share.share.formatted(.percent.precision(.fractionLength(0))))"
        }
    }
}

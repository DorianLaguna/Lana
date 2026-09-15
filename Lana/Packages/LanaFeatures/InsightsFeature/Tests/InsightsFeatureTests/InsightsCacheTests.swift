import Foundation
import LanaCore
import Testing
@testable import InsightsFeature

/// Analizar cuesta una lectura del store más dos llamadas al modelo. Volver a
/// un periodo que ya se vio en esta sesión no debe pagarlo otra vez.
@Suite("InsightsModel — lo ya analizado se recuerda")
@MainActor
struct InsightsCacheTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func expense(amount: Decimal, date: Date) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: "algo",
            category: "hogar",
            date: date)
    }

    private func freshDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "lana.tests.\(UUID().uuidString)"))
    }

    private func makeModel(
        store: CountingExpenseStore,
        narrator: CountingNarrator = CountingNarrator(),
        defaults: UserDefaults,
        referenceDate: Date) -> InsightsModel {
        InsightsModel(
            store: store,
            sharedListStore: InMemorySharedListStore(),
            classifier: InMemorySpendingClassifying(groupsByLabel: ["hogar": .necesidad]),
            narrator: narrator,
            preference: BudgetRulePreference(userDefaults: defaults),
            referenceDate: referenceDate,
            calendar: calendar)
    }

    @Test("Volver a un periodo ya analizado no vuelve a leer el store ni a llamar al modelo")
    func volverAUnPeriodoYaAnalizadoNoRecalcula() async throws {
        let store = try CountingExpenseStore(seed: [
            expense(amount: 100, date: date(2026, 3, 10)),
            expense(amount: 900, date: date(2026, 2, 10))
        ])
        let narrator = CountingNarrator()
        let model = try makeModel(
            store: store,
            narrator: narrator,
            defaults: freshDefaults(),
            referenceDate: date(2026, 3, 15))

        await model.onAppear()
        await model.goToPrevious()
        let readsAfterTwo = await store.readCount
        let narrationsAfterTwo = await narrator.count

        await model.goToNext()

        #expect(await store.readCount == readsAfterTwo)
        #expect(await narrator.count == narrationsAfterTwo)
        // Y sigue mostrando lo correcto, no un hueco.
        #expect(model.shares.first { $0.group == .necesidad }?.amount == 100)
    }

    @Test("Alternar entre mes y año recuerda cada uno por separado")
    func alternarEntreMesYAnioRecuerdaCadaUno() async throws {
        let store = try CountingExpenseStore(seed: [
            expense(amount: 100, date: date(2026, 3, 10)),
            expense(amount: 900, date: date(2026, 8, 10))
        ])
        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))

        await model.onAppear()
        await model.select(.year)
        let readsAfterBoth = await store.readCount

        await model.select(.month)
        await model.select(.year)

        #expect(await store.readCount == readsAfterBoth)
        // El año sigue siendo el año: 100 + 900.
        #expect(model.shares.first { $0.group == .necesidad }?.amount == 1000)
    }

    @Test("Cerrar la pantalla tira lo recordado — al reabrir los datos pueden ser otros")
    func cerrarLaPantallaTiraLoRecordado() async throws {
        let store = try CountingExpenseStore(seed: [expense(amount: 100, date: date(2026, 3, 10))])
        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))

        await model.onAppear()
        let readsAfterFirst = await store.readCount

        model.onDismiss()
        await model.onAppear()

        #expect(await store.readCount > readsAfterFirst)
    }

    @Test("Cerrar la pantalla también limpia la pregunta y su respuesta")
    func cerrarLimpiaLaPreguntaYSuRespuesta() throws {
        let store = try CountingExpenseStore(seed: [expense(amount: 100, date: date(2026, 3, 10))])
        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        model.question = "¿cuánto gasté?"

        model.onDismiss()

        #expect(model.question.isEmpty)
        #expect(model.answer == nil)
    }

    @Test("Descartar la sugerencia no la resucita al volver a un periodo ya visto")
    func descartarNoResucitaLaSugerencia() async throws {
        var seeded = [Expense]()
        for day in 1 ... 10 {
            try seeded.append(expense(amount: 100, date: date(2026, 1, day)))
            try seeded.append(expense(amount: 100, date: date(2026, 2, day)))
        }
        try seeded.append(Expense(
            kind: .income,
            amount: Money(amount: 30000, currency: .mxn),
            concept: "sueldo",
            date: date(2026, 1, 1)))

        let store = CountingExpenseStore(seed: seeded)
        let model = try InsightsModel(
            store: store,
            sharedListStore: InMemorySharedListStore(),
            classifier: InMemorySpendingClassifying(groupsByLabel: ["hogar": .necesidad]),
            narrator: InMemoryInsightNarrating(
                recommendation: BudgetRuleRecommendation(rule: .fiftyThirtyTwenty, reason: "porque sí")),
            preference: BudgetRulePreference(userDefaults: freshDefaults()),
            referenceDate: date(2026, 2, 15),
            calendar: calendar)

        await model.select(.year)
        #expect(model.suggestion != nil)
        model.dismissSuggestion()

        await model.select(.month)
        await model.select(.year)

        #expect(model.suggestion == nil)
    }
}

/// Cuenta lecturas, para probar que lo recordado no vuelve a pegarle al store.
private actor CountingExpenseStore: ExpenseStore {
    private var storage: [Expense]
    private(set) var readCount = 0

    init(seed: [Expense]) {
        storage = seed
    }

    func save(_ expense: Expense) async throws {
        storage.append(expense)
    }

    func expenses(in range: DateInterval) async throws -> [Expense] {
        readCount += 1
        return storage.filter { range.contains($0.date) }
    }

    func delete(id: Expense.ID) async throws {
        storage.removeAll { $0.id == id }
    }
}

/// Cuenta narraciones, para probar lo mismo del lado del modelo de lenguaje.
private actor CountingNarrator: InsightNarrating {
    private(set) var count = 0

    nonisolated var availability: ParsingAvailability {
        get async { .available }
    }

    func narrate(_: PeriodFacts) async throws -> PeriodNarrative {
        count += 1
        return PeriodNarrative(summary: "Resumen")
    }

    func recommendRule(mix _: [String], from _: [BudgetRule]) async throws -> BudgetRuleRecommendation? {
        nil
    }
}

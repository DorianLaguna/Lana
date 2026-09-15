import Foundation
import LanaCore
import Testing
@testable import InsightsFeature

@Suite("InsightsModel")
@MainActor
struct InsightsModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func expense(
        kind: Expense.Kind = .expense,
        amount: Decimal,
        currency: Currency = .mxn,
        category: String? = "hogar",
        date: Date) -> Expense {
        Expense(
            kind: kind,
            amount: Money(amount: amount, currency: currency),
            concept: "algo",
            category: category,
            date: date)
    }

    private func freshDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "lana.tests.\(UUID().uuidString)"))
    }

    private func makeModel(
        store: InMemoryExpenseStore,
        classifier: InMemorySpendingClassifying = InMemorySpendingClassifying(
            groupsByLabel: ["hogar": .necesidad, "ocio": .deseo]),
        narrator: InMemoryInsightNarrating = InMemoryInsightNarrating(
            narrative: PeriodNarrative(summary: "Resumen")),
        defaults: UserDefaults,
        referenceDate: Date) -> InsightsModel {
        InsightsModel(
            store: store,
            sharedListStore: InMemorySharedListStore(),
            classifier: classifier,
            narrator: narrator,
            preference: BudgetRulePreference(userDefaults: defaults),
            referenceDate: referenceDate,
            calendar: calendar)
    }

    @Test("Sin Apple Intelligence no analiza nada y lo reporta")
    func sinAppleIntelligenceNoAnaliza() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 10)))

        let model = try makeModel(
            store: store,
            classifier: InMemorySpendingClassifying(availability: .deviceNotEligible),
            defaults: freshDefaults(),
            referenceDate: date(2026, 3, 15))
        await model.onAppear()

        #expect(model.availability == .deviceNotEligible)
        #expect(model.mix == nil)
        #expect(model.narrative == nil)
    }

    @Test("Analiza solo el mes cuando el periodo es el mes")
    func analizaSoloElMes() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 10)))
        try await store.save(expense(amount: 900, date: date(2026, 5, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.onAppear()

        let necesidad = try #require(model.shares.first { $0.group == .necesidad })
        #expect(necesidad.amount == 100)
    }

    @Test("Cambiar a año amplía el rango")
    func cambiarAAnioAmpliaElRango() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 10)))
        try await store.save(expense(amount: 900, date: date(2026, 5, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.onAppear()
        await model.select(.year)

        let necesidad = try #require(model.shares.first { $0.group == .necesidad })
        #expect(necesidad.amount == 1000)
    }

    @Test("Arranca sin regla y por lo tanto sin metas")
    func arrancaSinReglaYSinMetas() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(kind: .income, amount: 10000, category: nil, date: date(2026, 3, 1)))
        try await store.save(expense(amount: 5000, date: date(2026, 3, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.onAppear()

        #expect(model.selectedRule == nil)
        #expect(model.shares.allSatisfy { $0.target == nil })
    }

    @Test("Elegir una regla trae las metas sin volver a leer el store")
    func elegirUnaReglaTraeLasMetas() async throws {
        let store = try CountingExpenseStore(seed: [
            expense(kind: .income, amount: 10000, category: nil, date: date(2026, 3, 1)),
            expense(amount: 5000, date: date(2026, 3, 10))
        ])

        let model = try InsightsModel(
            store: store,
            sharedListStore: InMemorySharedListStore(),
            classifier: InMemorySpendingClassifying(groupsByLabel: ["hogar": .necesidad]),
            narrator: InMemoryInsightNarrating(),
            preference: BudgetRulePreference(userDefaults: freshDefaults()),
            referenceDate: date(2026, 3, 15),
            calendar: calendar)
        await model.onAppear()
        let readsAfterLoad = await store.readCount

        model.selectRule(.fiftyThirtyTwenty)

        let necesidad = try #require(model.shares.first { $0.group == .necesidad })
        #expect(necesidad.target == Decimal(string: "0.50"))
        // Lo que hace barato dejar la regla en manos del usuario: cambiarla no
        // vuelve a leer ni a clasificar nada.
        #expect(await store.readCount == readsAfterLoad)
    }

    @Test("Cambiar de regla no mueve los porcentajes reales")
    func cambiarDeReglaNoMueveLosPorcentajes() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(kind: .income, amount: 10000, category: nil, date: date(2026, 3, 1)))
        try await store.save(expense(amount: 7000, date: date(2026, 3, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.onAppear()

        model.selectRule(.fiftyThirtyTwenty)
        let clasica = try #require(model.shares.first { $0.group == .necesidad })
        model.selectRule(.seventyTwentyTen)
        let ajustada = try #require(model.shares.first { $0.group == .necesidad })

        #expect(clasica.share == ajustada.share)
        #expect(clasica.target != ajustada.target)
    }

    @Test("Sin material suficiente, Lana no sugiere ninguna regla")
    func sinMaterialNoSugiere() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 10)))

        let model = try makeModel(
            store: store,
            narrator: InMemoryInsightNarrating(
                recommendation: BudgetRuleRecommendation(rule: .fiftyThirtyTwenty, reason: "porque sí")),
            defaults: freshDefaults(),
            referenceDate: date(2026, 3, 15))
        await model.onAppear()

        #expect(model.suggestion == nil)
    }

    @Test("Descartar la sugerencia se recuerda entre aperturas")
    func descartarLaSugerenciaSeRecuerda() async throws {
        let defaults = try freshDefaults()
        let store = InMemoryExpenseStore()
        try await store.save(expense(kind: .income, amount: 30000, category: nil, date: date(2026, 1, 1)))
        for day in 1 ... 10 {
            try await store.save(expense(amount: 100, date: date(2026, 1, day)))
            try await store.save(expense(amount: 100, date: date(2026, 2, day)))
        }

        let narrator = InMemoryInsightNarrating(
            recommendation: BudgetRuleRecommendation(rule: .fiftyThirtyTwenty, reason: "porque sí"))
        let model = try makeModel(
            store: store,
            narrator: narrator,
            defaults: defaults,
            referenceDate: date(2026, 2, 15))
        await model.select(.year)
        #expect(model.suggestion != nil)

        model.dismissSuggestion()
        #expect(model.suggestion == nil)

        // Una instancia nueva sobre los mismos defaults: relanzar la app.
        let reopened = try makeModel(
            store: store,
            narrator: narrator,
            defaults: defaults,
            referenceDate: date(2026, 2, 15))
        await reopened.select(.year)
        #expect(reopened.suggestion == nil)
    }

    @Test("Con una regla ya elegida, tampoco se sugiere otra")
    func conReglaElegidaNoSeSugiere() async throws {
        let defaults = try freshDefaults()
        BudgetRulePreference(userDefaults: defaults).setRule(.sixtyTwentyTwenty)

        let store = InMemoryExpenseStore()
        try await store.save(expense(kind: .income, amount: 30000, category: nil, date: date(2026, 1, 1)))
        for day in 1 ... 10 {
            try await store.save(expense(amount: 100, date: date(2026, 1, day)))
            try await store.save(expense(amount: 100, date: date(2026, 2, day)))
        }

        let model = try makeModel(
            store: store,
            narrator: InMemoryInsightNarrating(
                recommendation: BudgetRuleRecommendation(rule: .fiftyThirtyTwenty, reason: "porque sí")),
            defaults: defaults,
            referenceDate: date(2026, 2, 15))
        await model.select(.year)

        #expect(model.suggestion == nil)
    }

    @Test("Con dos monedas analiza la de más gasto y reporta la otra, sin cruzarlas")
    func conDosMonedasAnalizaLaPrincipal() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 5000, currency: .mxn, date: date(2026, 3, 10)))
        try await store.save(expense(amount: 40, currency: .usd, date: date(2026, 3, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.onAppear()

        #expect(model.analyzedCurrency == .mxn)
        #expect(model.otherCurrencies == [.usd])
        let necesidad = try #require(model.shares.first { $0.group == .necesidad })
        #expect(necesidad.amount == 5000)
    }

    @Test("Un periodo sin movimientos no inventa análisis")
    func unPeriodoVacioNoInventaAnalisis() async throws {
        let model = try makeModel(
            store: InMemoryExpenseStore(),
            defaults: freshDefaults(),
            referenceDate: date(2026, 3, 15))
        await model.onAppear()

        #expect(model.mix == nil)
        #expect(model.shares.isEmpty)
    }
}

/// Un store que cuenta cuántas veces se le leyó — para probar que cambiar de
/// regla no dispara una lectura nueva.
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

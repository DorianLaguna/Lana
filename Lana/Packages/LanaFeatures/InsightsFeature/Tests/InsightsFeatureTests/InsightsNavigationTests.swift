import Foundation
import LanaCore
import Testing
@testable import InsightsFeature

/// Elegir qué mes o qué año se analiza. Antes el análisis solo sabía ver el
/// periodo en curso, y un mes ya cerrado es justo el que vale la pena entender.
@Suite("InsightsModel — elegir el periodo")
@MainActor
struct InsightsNavigationTests {
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

    @Test("Se puede analizar un mes que no es el actual")
    func sePuedeAnalizarUnMesQueNoEsElActual() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 10)))
        try await store.save(expense(amount: 900, date: date(2026, 2, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.onAppear()
        await model.goToPrevious()

        // Contra la fecha y no contra el texto: la etiqueta sigue el idioma del
        // dispositivo, igual que el selector de mes del Dashboard.
        #expect(calendar.component(.month, from: model.anchor) == 2)
        let necesidad = try #require(model.shares.first { $0.group == .necesidad })
        #expect(necesidad.amount == 900)
    }

    @Test("Estando en año, navegar mueve años y no meses")
    func estandoEnAnioNavegarMueveAnios() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 10)))
        try await store.save(expense(amount: 700, date: date(2025, 8, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.select(.year)
        await model.goToPrevious()

        #expect(model.anchorYear == 2025)
        let necesidad = try #require(model.shares.first { $0.group == .necesidad })
        #expect(necesidad.amount == 700)
    }

    @Test("Cambiar de periodo tira lo del periodo anterior, no lo deja en pantalla")
    func cambiarDePeriodoTiraLoAnterior() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.onAppear()
        #expect(model.mix != nil)

        // Un mes sin nada: no debe quedar la mezcla de marzo colgada.
        await model.goToNext()

        #expect(model.mix == nil)
        #expect(model.narrative == nil)
        #expect(model.shares.isEmpty)
    }

    @Test("Volver al mes de origen recupera sus cifras")
    func volverAlMesDeOrigenRecuperaSusCifras() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 10)))

        let model = try makeModel(store: store, defaults: freshDefaults(), referenceDate: date(2026, 3, 15))
        await model.onAppear()
        await model.goToPrevious()
        await model.goToNext()

        #expect(calendar.component(.month, from: model.anchor) == 3)
        let necesidad = try #require(model.shares.first { $0.group == .necesidad })
        #expect(necesidad.amount == 100)
    }
}

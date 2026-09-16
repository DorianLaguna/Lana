import Foundation
import LanaCore
import Testing
@testable import InsightsFeature

/// Los hallazgos son aritmética sobre lo ya registrado, no narración.
///
/// Lo que cuidan estas pruebas es que se carguen **por su propio camino**: si
/// alguien los mete dentro de la guarda de disponibilidad que envuelve al
/// análisis narrado, la pantalla vuelve en silencio a quedarse muda sin Apple
/// Intelligence — que es justo el problema que se acaba de arreglar.
@Suite("InsightsModel — hallazgos")
@MainActor
struct InsightsFindingsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    private func expense(_ amount: Decimal, on date: Date) -> Expense {
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
        store: any ExpenseStore,
        availability: ParsingAvailability = .available,
        defaults: UserDefaults,
        referenceDate: Date) -> InsightsModel {
        InsightsModel(
            store: store,
            sharedListStore: InMemorySharedListStore(),
            classifier: InMemorySpendingClassifying(
                groupsByLabel: ["hogar": .necesidad],
                availability: availability),
            narrator: InMemoryInsightNarrating(narrative: PeriodNarrative(summary: "Resumen")),
            preference: BudgetRulePreference(userDefaults: defaults),
            referenceDate: referenceDate,
            calendar: calendar)
    }

    /// Dos meses con montos distintos: un hallazgo que compara no existe sin
    /// mes anterior, así que sembrar uno solo dejaría la prueba vacía y sin
    /// probar nada.
    private func twoMonths() throws -> InMemoryExpenseStore {
        try InMemoryExpenseStore(seed: [
            expense(700, on: date(2026, 8, 10)),
            expense(1900, on: date(2026, 9, 10))
        ])
    }

    @Test("Los hallazgos salen aunque no haya Apple Intelligence")
    func losHallazgosSalenSinAppleIntelligence() async throws {
        let model = try makeModel(
            store: twoMonths(),
            availability: .deviceNotEligible,
            defaults: freshDefaults(),
            referenceDate: date(2026, 9, 15))

        await model.onAppear()

        // El análisis narrado sí se apaga: ese necesita el modelo.
        #expect(model.availability == .deviceNotEligible)
        #expect(model.narrative == nil)
        // Los hallazgos no.
        #expect(!model.findings.isEmpty)
    }

    @Test("Viendo el año no se ofrecen hallazgos: los detectores comparan meses")
    func viendoElAnioNoHayHallazgos() async throws {
        let model = try makeModel(
            store: twoMonths(),
            defaults: freshDefaults(),
            referenceDate: date(2026, 9, 15))
        await model.onAppear()
        #expect(!model.findings.isEmpty)

        await model.select(.year)

        #expect(model.findings.isEmpty)
    }

    @Test("Volver a un mes ya visto no vuelve a leer el store")
    func volverAUnMesYaVistoNoRelee() async throws {
        let store = try CountingExpenseStore(seed: [
            expense(700, on: date(2026, 8, 10)),
            expense(1900, on: date(2026, 9, 10))
        ])
        let model = try makeModel(
            store: store,
            defaults: freshDefaults(),
            referenceDate: date(2026, 9, 15))

        await model.onAppear()
        let readsAfterFirstLoad = await store.readCount
        await model.goToPrevious()
        await model.goToNext()

        #expect(await store.readCount > readsAfterFirstLoad)
        let readsAfterReturning = await store.readCount
        await model.goToPrevious()
        await model.goToNext()

        // La segunda ida y vuelta sale de lo recordado: ni una lectura más.
        #expect(await store.readCount == readsAfterReturning)
    }

    @Test("Cerrar la pantalla también tira los hallazgos recordados")
    func cerrarTiraLosHallazgos() async throws {
        let model = try makeModel(
            store: twoMonths(),
            defaults: freshDefaults(),
            referenceDate: date(2026, 9, 15))
        await model.onAppear()
        #expect(!model.findings.isEmpty)

        model.onDismiss()

        #expect(model.findings.isEmpty)
    }
}

/// Cuenta lecturas, para probar que lo ya resuelto no se vuelve a leer.
///
/// Es el tercero con este nombre en la suite: los otros dos son `private` a su
/// propio archivo y no se pueden compartir. Juntarlos en un solo doble es una
/// limpieza que vale la pena, pero toca dos suites verdes por un motivo ajeno a
/// los hallazgos, así que va en su propio cambio.
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

import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("YearModel")
@MainActor
struct YearModelTests {
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
        category: String? = "otro",
        date: Date) -> Expense {
        Expense(
            kind: kind,
            amount: Money(amount: amount, currency: currency),
            concept: "algo",
            category: category,
            date: date)
    }

    private func model(store: InMemoryExpenseStore, referenceDate: Date) -> YearModel {
        YearModel(
            store: store,
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore(),
            referenceDate: referenceDate,
            calendar: calendar)
    }

    @Test("Al aparecer carga solo los movimientos del año de referencia")
    func cargaSoloLosMovimientosDelAnio() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 1)))
        try await store.save(expense(amount: 200, date: date(2025, 3, 1)))

        let model = try model(store: store, referenceDate: date(2026, 6, 1))
        await model.onAppear()

        #expect(model.year == 2026)
        #expect(model.expenses.count == 1)
        #expect(model.statistics.period.total(in: .mxn)?.expenses == 100)
    }

    @Test("La serie del año trae doce puntos, con los meses vacíos marcados")
    func laSerieTraeDocePuntos() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 500, date: date(2026, 2, 14)))

        let model = try model(store: store, referenceDate: date(2026, 6, 1))
        await model.onAppear()

        let points = model.statistics.monthlyPoints(in: .mxn)
        #expect(points.count == 12)
        #expect(points[1].expenses == 500)
        #expect(points[0].hasActivity == false)
    }

    @Test("Ir al año anterior recarga con los movimientos de ese año")
    func irAlAnioAnteriorRecarga() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 1)))
        try await store.save(expense(amount: 200, date: date(2025, 3, 1)))

        let model = try model(store: store, referenceDate: date(2026, 6, 1))
        await model.onAppear()
        await model.goToPreviousYear()

        #expect(model.year == 2025)
        #expect(model.statistics.period.total(in: .mxn)?.expenses == 200)
    }

    @Test("De un gasto compartido, el año suma solo la parte de quien mira")
    func elAnioSumaSoloLaParteDeQuienMira() async throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let list = SharedList(
            name: "Casa",
            participants: [
                Participant(id: alice, displayName: "Alice"),
                Participant(id: bob, displayName: "Bob")
            ],
            defaultSplit: .equally(among: [alice, bob]))
        let sharedListStore = InMemorySharedListStore()
        try await sharedListStore.save(list)
        try await sharedListStore.setViewerParticipantID(bob, for: list.id)

        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 1000, currency: .mxn),
            concept: "renta",
            category: "hogar",
            date: date(2026, 3, 1),
            sharedListID: list.id,
            payer: alice,
            split: .equally(among: [alice, bob])))

        let model = try YearModel(
            store: store,
            cardStore: InMemoryCardStore(),
            sharedListStore: sharedListStore,
            referenceDate: date(2026, 6, 1),
            calendar: calendar)
        await model.onAppear()

        #expect(model.statistics.period.total(in: .mxn)?.expenses == 500)
    }

    @Test("La comparación contra el mes anterior cruza el fin de año")
    func laComparacionCruzaElFinDeAnio() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 800, date: date(2025, 12, 15)))
        try await store.save(expense(amount: 1000, date: date(2026, 1, 15)))

        let model = try model(store: store, referenceDate: date(2026, 2, 1))
        await model.onAppear()

        // Enero de 2026 contra diciembre de 2025 — el mes anterior vive en el
        // año pasado, que es justo por lo que se cargan veinticuatro meses.
        let delta = try #require(model.comparisonWithPreviousMonth?.expenseDelta(in: .mxn))
        #expect(delta.current == 1000)
        #expect(delta.previous == 800)
        #expect(delta.absolute == 200)
    }

    @Test("La comparación contra el mismo mes del año pasado usa ese mes, no el total del año")
    func laComparacionContraElAnioPasadoUsaElMismoMes() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 300, date: date(2025, 5, 10)))
        try await store.save(expense(amount: 900, date: date(2025, 8, 10)))
        try await store.save(expense(amount: 400, date: date(2026, 5, 10)))

        let model = try model(store: store, referenceDate: date(2026, 6, 1))
        await model.onAppear()

        let delta = try #require(model.comparisonWithSameMonthLastYear?.expenseDelta(in: .mxn))
        #expect(delta.current == 400)
        #expect(delta.previous == 300)
    }

    @Test("Sin movimientos en el año no hay comparaciones que mostrar")
    func sinMovimientosNoHayComparaciones() async throws {
        let model = try model(store: InMemoryExpenseStore(), referenceDate: date(2026, 6, 1))
        await model.onAppear()

        #expect(model.latestActiveMonth == nil)
        #expect(model.comparisonWithPreviousMonth == nil)
        #expect(model.comparisonWithSameMonthLastYear == nil)
    }

    @Test("El drill-down por categoría del año deriva del año, no de un mes")
    func elDrillDownDeCategoriaDerivaDelAnio() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, category: "comida", date: date(2026, 1, 5)))
        try await store.save(expense(amount: 250, category: "comida", date: date(2026, 9, 5)))
        try await store.save(expense(amount: 999, category: "ocio", date: date(2026, 9, 5)))

        let model = try model(store: store, referenceDate: date(2026, 10, 1))
        await model.onAppear()
        let detail = model.makeCategoryDetailModel(for: "comida")

        #expect(detail.expenses.count == 2)
        #expect(detail.total == 350)
    }

    @Test("Un gasto justo en la medianoche de fin de año cae en un solo año")
    func medianocheDeFinDeAnioCaeEnUnSoloAnio() async throws {
        let lastMoment = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 59, second: 59)))
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: lastMoment))
        try await store.save(expense(amount: 200, date: date(2027, 1, 1)))

        let model = try model(store: store, referenceDate: date(2027, 6, 1))
        await model.onAppear()

        #expect(model.year == 2027)
        #expect(model.statistics.period.total(in: .mxn)?.expenses == 200)

        await model.goToPreviousYear()
        #expect(model.statistics.period.total(in: .mxn)?.expenses == 100)
    }
}

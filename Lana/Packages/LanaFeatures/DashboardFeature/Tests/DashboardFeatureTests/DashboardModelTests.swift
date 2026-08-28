import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("DashboardModel")
@MainActor
struct DashboardModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func expense(
        kind: Expense.Kind = .expense,
        amount: Decimal,
        currency: Currency = .mxn,
        concept: String = "algo",
        category: String? = "otro",
        date: Date,
        paymentMethod: PaymentMethod? = nil,
        needsReview: Bool = false) -> Expense {
        Expense(
            kind: kind,
            amount: Money(amount: amount, currency: currency),
            concept: concept,
            category: category,
            date: date,
            paymentMethod: paymentMethod,
            needsReview: needsReview)
    }

    @Test("Carga los movimientos del mes de referencia al aparecer")
    func cargaMovimientosDelMesDeReferencia() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 8, 15)))
        try await store.save(expense(amount: 200, date: date(2026, 9, 1)))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        #expect(model.expenses.count == 1)
        #expect(model.expenses.first?.amount.amount == 100)
    }

    @Test("Ir al mes anterior recarga con los movimientos de ese mes")
    func irAlMesAnteriorRecarga() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 7, 20)))
        try await store.save(expense(amount: 200, date: date(2026, 8, 20)))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()
        #expect(model.expenses.count == 1)

        await model.goToPreviousMonth()
        #expect(model.expenses.count == 1)
        #expect(model.expenses.first?.amount.amount == 100)
    }

    @Test("Agrupa por día, el más reciente primero")
    func agrupaPorDiaMasRecientePrimero() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 50, date: date(2026, 8, 5)))
        try await store.save(expense(amount: 60, date: date(2026, 8, 5)))
        try await store.save(expense(amount: 70, date: date(2026, 8, 10)))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 15),
            calendar: calendar)
        await model.onAppear()

        let sections = model.daySections
        #expect(sections.count == 2)
        #expect(sections.first?.items.count == 1)
        #expect(sections.last?.items.count == 2)
    }

    @Test("Los totales del mes separan gastos e ingresos, sin mezclar monedas")
    func totalesDelMesSeparanGastosEIngresosSinMezclarMonedas() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, currency: .mxn, date: date(2026, 8, 5)))
        try await store.save(expense(
            kind: .income,
            amount: 5000,
            currency: .mxn,
            category: nil,
            date: date(2026, 8, 5)))
        try await store.save(expense(amount: 20, currency: .usd, date: date(2026, 8, 6)))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        let totals = model.monthTotals
        #expect(totals.count == 2)
        let mxn = try #require(totals.first { $0.currency == .mxn })
        #expect(mxn.expenses == 100)
        #expect(mxn.income == 5000)
        let usd = try #require(totals.first { $0.currency == .usd })
        #expect(usd.expenses == 20)
        #expect(usd.income == 0)
    }

    @Test("El desglose por forma de pago suma solo gastos, sin efectivo explícito cae ahí")
    func desglosePorFormaDePago() async throws {
        let cardID = CardID()
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 8, 5), paymentMethod: .cash))
        try await store.save(expense(amount: 50, date: date(2026, 8, 5), paymentMethod: nil))
        try await store.save(expense(amount: 200, date: date(2026, 8, 6), paymentMethod: .credit(cardID: cardID)))
        try await store.save(expense(amount: 80, date: date(2026, 8, 6), paymentMethod: .transfer))
        try await store.save(expense(
            kind: .income,
            amount: 5000,
            category: nil,
            date: date(2026, 8, 6),
            paymentMethod: .transfer))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        let totals = model.paymentMethodTotals
        #expect(totals.first { $0.category == "efectivo" }?.amount == 150)
        #expect(totals.first { $0.category == "crédito" }?.amount == 200)
        #expect(totals.first { $0.category == "transferencia" }?.amount == 80)
        #expect(!totals.contains { $0.category == "débito" })
    }

    @Test("El desglose por categoría suma solo gastos, no ingresos")
    func desglosePorCategoriaSumaSoloGastos() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, category: "despensa", date: date(2026, 8, 5)))
        try await store.save(expense(amount: 50, category: "despensa", date: date(2026, 8, 6)))
        try await store.save(expense(amount: 200, category: "transporte", date: date(2026, 8, 7)))
        try await store.save(expense(kind: .income, amount: 5000, category: nil, date: date(2026, 8, 8)))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        let totals = model.categoryTotals
        let despensa = try #require(totals.first { $0.category == "despensa" })
        #expect(despensa.amount == 150)
        #expect(totals.reduce(0) { $0 + $1.amount } == 350)
    }

    @Test("categoryTotals(in:) solo trae la moneda pedida")
    func categoryTotalsEnUnaMonedaSoloTraeEsaMoneda() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, currency: .mxn, category: "despensa", date: date(2026, 8, 5)))
        try await store.save(expense(amount: 20, currency: .usd, category: "ocio", date: date(2026, 8, 6)))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        let mxnTotals = model.categoryTotals(in: .mxn)
        #expect(mxnTotals.map(\.category) == ["despensa"])
        #expect(mxnTotals.allSatisfy { $0.currency == .mxn })
    }

    @Test("needsReviewItems solo trae lo marcado para revisar")
    func needsReviewItemsSoloTraeLoMarcado() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 45000, date: date(2026, 8, 5), needsReview: true))
        try await store.save(expense(amount: 100, date: date(2026, 8, 6), needsReview: false))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        #expect(model.needsReviewItems.count == 1)
        #expect(model.needsReviewItems.first?.amount.amount == 45000)
    }

    @Test("makeCategoryDetailModel hereda el mes vigente del dashboard")
    func makeCategoryDetailModelHeredaElMes() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, category: "despensa", date: date(2026, 8, 5)))
        try await store.save(expense(amount: 50, category: "despensa", date: date(2026, 7, 5)))

        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()
        await model.goToPreviousMonth()

        let detail = model.makeCategoryDetailModel(for: "despensa")
        await detail.onAppear()

        #expect(detail.expenses.count == 1)
        #expect(detail.total == 50)
    }
}

@Suite("CategoryDetailModel")
@MainActor
struct CategoryDetailModelTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func expense(
        amount: Decimal,
        category: String,
        subcategory: String? = nil,
        date: Date) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: "algo",
            category: category,
            subcategory: subcategory,
            date: date)
    }

    @Test("Filtra solo la categoría pedida, sin tocar las demás")
    func filtraSoloLaCategoriaPedida() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, category: "despensa", date: date(2026, 8, 5)))
        try await store.save(expense(amount: 200, category: "transporte", date: date(2026, 8, 6)))

        let model = CategoryDetailModel(
            category: "despensa",
            store: store,
            month: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        #expect(model.expenses.count == 1)
        #expect(model.total == 100)
    }

    @Test("El desglose por subcategoría suma correctamente")
    func desglosePorSubcategoriaSumaCorrectamente() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(
            amount: 100,
            category: "despensa",
            subcategory: "abarrotes",
            date: date(2026, 8, 5)))
        try await store.save(expense(
            amount: 50,
            category: "despensa",
            subcategory: "abarrotes",
            date: date(2026, 8, 6)))
        try await store.save(expense(amount: 30, category: "despensa", subcategory: "limpieza", date: date(2026, 8, 7)))

        let model = CategoryDetailModel(
            category: "despensa",
            store: store,
            month: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        let totals = model.subcategoryTotals
        let abarrotes = try #require(totals.first { $0.subcategory == "abarrotes" })
        #expect(abarrotes.amount == 150)
    }
}

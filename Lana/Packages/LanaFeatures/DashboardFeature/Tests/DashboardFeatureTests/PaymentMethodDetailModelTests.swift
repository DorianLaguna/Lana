import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("PaymentMethodDetailModel")
@MainActor
struct PaymentMethodDetailModelTests {
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
        paymentMethod: PaymentMethod?,
        date: Date) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: "algo",
            category: category,
            date: date,
            paymentMethod: paymentMethod)
    }

    @Test("Filtra solo la forma de pago pedida, sin tocar las demás")
    func filtraSoloLaFormaDePagoPedida() async throws {
        let cardID = CardID()
        let store = InMemoryExpenseStore()
        try await store.save(expense(
            amount: 100,
            category: "despensa",
            paymentMethod: .credit(cardID: cardID),
            date: date(2026, 8, 5)))
        try await store.save(expense(amount: 200, category: "transporte", paymentMethod: .cash, date: date(2026, 8, 6)))

        let model = PaymentMethodDetailModel(
            label: "crédito",
            store: store,
            cardStore: InMemoryCardStore(),
            month: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        #expect(model.expenses.count == 1)
        #expect(model.total == 100)
    }

    @Test("Sin forma de pago explícita cuenta como efectivo")
    func sinFormaDePagoExplicitaCuentaComoEfectivo() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 50, category: "comida", paymentMethod: nil, date: date(2026, 8, 5)))

        let model = PaymentMethodDetailModel(
            label: "efectivo",
            store: store,
            cardStore: InMemoryCardStore(),
            month: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        #expect(model.expenses.count == 1)
    }

    @Test("El desglose por categoría suma correctamente")
    func desglosePorCategoriaSumaCorrectamente() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, category: "despensa", paymentMethod: .cash, date: date(2026, 8, 5)))
        try await store.save(expense(amount: 50, category: "despensa", paymentMethod: .cash, date: date(2026, 8, 6)))
        try await store.save(expense(amount: 30, category: "transporte", paymentMethod: .cash, date: date(2026, 8, 7)))

        let model = PaymentMethodDetailModel(
            label: "efectivo",
            store: store,
            cardStore: InMemoryCardStore(),
            month: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()

        let totals = model.categoryTotals
        let despensa = try #require(totals.first { $0.category == "despensa" })
        #expect(despensa.amount == 150)
    }
}

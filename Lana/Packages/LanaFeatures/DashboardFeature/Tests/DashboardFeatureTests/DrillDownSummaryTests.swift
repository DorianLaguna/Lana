import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("Resumen de un drill-down")
@MainActor
struct DrillDownSummaryTests {
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

    private func movement(_ kind: Expense.Kind, amount: Decimal, category: String?, day: Int) -> Expense {
        Expense(
            kind: kind,
            amount: Money(amount: amount, currency: .mxn),
            concept: "algo",
            category: category,
            date: date(2026, 8, day),
            paymentMethod: .cash)
    }

    private func loadedDashboard(_ movements: [Expense]) async throws -> DashboardModel {
        let store = InMemoryExpenseStore()
        for movement in movements {
            try await store.save(movement)
        }
        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore(),
            referenceDate: date(2026, 8, 10),
            calendar: calendar)
        await model.onAppear()
        return model
    }

    @Test("Dice cuántos gastos son y qué parte del mes pesan, sin contar ingresos")
    func resumenDiceParteDelMes() async throws {
        let dashboard = try await loadedDashboard([
            movement(.expense, amount: 35, category: "despensa", day: 5),
            movement(.expense, amount: 65, category: "transporte", day: 6),
            movement(.income, amount: 1000, category: nil, day: 7)
        ])

        let category = CategoryDetailModel(category: "despensa", source: dashboard)
        #expect(abs(category.periodShare - 0.35) < 0.0001)
        #expect(category.summary == "1 gasto · 35% de tu mes")
        #expect(category.totalLabel == "Total en el mes")

        let payment = PaymentMethodDetailModel(label: "efectivo", source: dashboard, cardStore: InMemoryCardStore())
        #expect(payment.summary == "2 gastos · 100% de tu mes")
    }

    @Test("Sin gastos en el periodo no inventa un porcentaje")
    func resumenSinGastos() {
        #expect(drillDownSummary(count: 0, share: 0, periodNoun: "mes") == "0 gastos")
        #expect(drillDownSummary(count: 11, share: 0.346, periodNoun: "año") == "11 gastos · 35% de tu año")
        #expect(fraction(10, of: 0) == 0)
    }
}

import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("Recurrentes — cómo se agrupan en su pantalla")
@MainActor
struct RecurringItemsGroupingTests {
    private func item(
        _ name: String,
        kind: Expense.Kind = .expense,
        amount: Decimal = 1000,
        dayOfMonth: Int) throws -> RecurringItem {
        try RecurringItem(
            name: name,
            amount: Money(amount: amount, currency: .mxn),
            kind: kind,
            dayOfMonth: dayOfMonth)
    }

    private func makeModel(_ items: [RecurringItem]) async throws -> RecurringItemsModel {
        let store = InMemoryRecurringItemStore()
        for item in items {
            try await store.save(item)
        }
        let model = RecurringItemsModel(
            recurringItemStore: store,
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore())
        await model.onAppear()
        return model
    }

    @Test("Lo vencido y sin registrar queda pendiente; lo que aún no cae, no")
    func pendientesYPorVenir() async throws {
        let calendar = Calendar.current
        let today = calendar.component(.day, from: Date())
        // Un recurrente del día 1 ya venció en cualquier día del mes salvo el 1.
        let vencido = try item("Renta", dayOfMonth: 1)
        let porVenir = try item("Netflix", dayOfMonth: 28)
        let model = try await makeModel([vencido, porVenir])

        // El 28 o después, "Netflix" también habría vencido: el test se salta
        // ese tramo del mes en vez de afirmar algo falso.
        try #require(today < 28)

        #expect(model.pending().map(\.name) == ["Renta"])
        #expect(model.upcoming().map(\.name) == ["Netflix"])
    }

    @Test("El total mensual suma solo los gastos fijos, no los ingresos")
    func totalSoloDeGastos() async throws {
        let model = try await makeModel([
            item("Renta", amount: 9000, dayOfMonth: 1),
            item("Spotify", amount: 200, dayOfMonth: 5),
            item("Sueldo", kind: .income, amount: 20000, dayOfMonth: 15)
        ])

        #expect(model.monthlyExpenseTotal.first?.amount == 9200)
    }

    @Test("Los pendientes salen ordenados por el día en que caen")
    func ordenadosPorDia() async throws {
        let model = try await makeModel([
            item("Segundo", dayOfMonth: 3),
            item("Primero", dayOfMonth: 1)
        ])

        #expect(model.pending().map(\.name) == ["Primero", "Segundo"])
    }
}

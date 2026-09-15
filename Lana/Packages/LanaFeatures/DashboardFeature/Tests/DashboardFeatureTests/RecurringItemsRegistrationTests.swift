import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

/// Que un recurrente esté registrado sale de su movimiento, no de una marca
/// (ADR-0042): borrar el movimiento lo reabre, pero lo automático no insiste.
@Suite("RecurringItemsModel — registrado en el mes")
@MainActor
struct RecurringItemsRegistrationTests {
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

    private func makeModel(
        with item: RecurringItem,
        store: InMemoryExpenseStore) async throws -> RecurringItemsModel {
        let recurringItemStore = InMemoryRecurringItemStore()
        try await recurringItemStore.save(item)
        return RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: store,
            cardStore: InMemoryCardStore())
    }

    private func allExpenses(in store: InMemoryExpenseStore) async throws -> [Expense] {
        try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
    }

    @Test("Registrar liga el movimiento al recurrente, y borrarlo lo deja pendiente otra vez")
    func registrarLigaElMovimiento() async throws {
        let item = try RecurringItem(name: "Sueldo", amount: .zero(.mxn), kind: .income, dayOfMonth: 15)
        let store = InMemoryExpenseStore()
        let model = try await makeModel(with: item, store: store)

        try await model.register(item)
        await model.onAppear()

        let saved = try await allExpenses(in: store)
        #expect(saved.first?.recurringItemID == item.id)
        #expect(model.registrations[item.id] != nil)

        try await store.delete(id: #require(saved.first?.id))
        await model.onAppear()
        #expect(model.registrations[item.id] == nil)
    }

    @Test("Adelantar un recurrente y borrar el movimiento deja que se registre solo en su día")
    func adelantarYBorrarDejaQueSeRegistreSolo() async throws {
        let item = try RecurringItem(name: "Sueldo", amount: .zero(.mxn), kind: .income, dayOfMonth: 15)
        let store = InMemoryExpenseStore()
        let model = try await makeModel(with: item, store: store)

        try await model.register(item, on: date(2026, 9, 10))
        try await store.delete(id: #require(allExpenses(in: store).first?.id))
        await model.registerDueItems(asOf: date(2026, 9, 15), calendar: calendar)

        let saved = try await allExpenses(in: store)
        #expect(saved.count == 1)
        #expect(saved.first?.date == date(2026, 9, 15))
    }

    @Test("Borrar lo que registró el automático no hace que lo vuelva a postear solo")
    func borrarLoAutomaticoNoLoRepostea() async throws {
        let item = try RecurringItem(name: "Sueldo", amount: .zero(.mxn), kind: .income, dayOfMonth: 15)
        let store = InMemoryExpenseStore()
        let model = try await makeModel(with: item, store: store)

        await model.registerDueItems(asOf: date(2026, 9, 15), calendar: calendar)
        try await store.delete(id: #require(allExpenses(in: store).first?.id))
        await model.registerDueItems(asOf: date(2026, 9, 16), calendar: calendar)

        #expect(try await allExpenses(in: store).isEmpty)
    }

    @Test("Lo registrado con la marca heredada no se vuelve a registrar")
    func marcaHeredadaNoSeDuplica() async throws {
        let item = try RecurringItem(
            name: "Sueldo",
            amount: .zero(.mxn),
            kind: .income,
            dayOfMonth: 15,
            lastRegisteredMonth: date(2026, 9, 1))
        let store = InMemoryExpenseStore()
        let model = try await makeModel(with: item, store: store)

        await model.registerDueItems(asOf: date(2026, 9, 15), calendar: calendar)

        #expect(try await allExpenses(in: store).isEmpty)
    }
}

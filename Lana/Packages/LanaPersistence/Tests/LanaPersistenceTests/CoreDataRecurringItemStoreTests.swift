import Foundation
import LanaCore
import Testing
@testable import LanaPersistence

/// `CoreDataExpenseStore`'s `RecurringItemStore` conformance — extiende el
/// mismo tipo que `CoreDataExpenseStoreTests` (mismo `@Suite(.serialized)`,
/// definido ahí) en vez de declarar un `@Suite` nuevo: `.serialized` solo
/// serializa dentro de una suite, no entre suites, y cada test de aquí
/// crea su propio `NSPersistentContainer` — la misma razón por la que esa
/// suite existe.
extension CoreDataExpenseStoreTests {
    @Test("Guardar y leer un recurrente hace round-trip completo")
    func recurrenteHaceRoundTrip() async throws {
        let store = try await makeStore()
        let item = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 8000, currency: .mxn),
            kind: .expense,
            category: "hogar",
            dayOfMonth: 5)

        try await store.save(item)
        let results = try await store.items()

        #expect(results.count == 1)
        #expect(results.first?.id == item.id)
        #expect(results.first?.name == "Renta")
        #expect(results.first?.category == "hogar")
    }

    @Test("La subcategoría de un recurrente hace round-trip completo")
    func subcategoriaDeRecurrenteHaceRoundTrip() async throws {
        let store = try await makeStore()
        let item = try RecurringItem(
            name: "Streaming",
            amount: Money(amount: 199, currency: .mxn),
            kind: .expense,
            category: "entretenimiento",
            subcategory: "suscripciones",
            dayOfMonth: 3)

        try await store.save(item)
        let results = try await store.items()

        #expect(results.first?.subcategory == "suscripciones")
    }

    @Test("Un ingreso recurrente hace round-trip sin categoría")
    func ingresoRecurrenteHaceRoundTripSinCategoria() async throws {
        let store = try await makeStore()
        let item = try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 15000, currency: .mxn),
            kind: .income,
            dayOfMonth: 15)

        try await store.save(item)
        let results = try await store.items()

        #expect(results.first?.kind == .income)
        #expect(results.first?.category == nil)
    }

    @Test("Guardar de nuevo el mismo recurrente lo reemplaza, no lo duplica")
    func recurrenteGuardarDeNuevoReemplaza() async throws {
        let store = try await makeStore()
        var item = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 8000, currency: .mxn),
            kind: .expense,
            dayOfMonth: 5)
        try await store.save(item)

        item.amount = Money(amount: 8500, currency: .mxn)
        try await store.save(item)

        let results = try await store.items()
        #expect(results.count == 1)
        #expect(results.first?.amount.amount == 8500)
    }

    @Test("Con qué se paga y el último mes registrado hacen round-trip completo")
    func pagoYUltimoMesRegistradoHacenRoundTrip() async throws {
        let store = try await makeStore()
        let cardID = CardID()
        let monthStart = Date(timeIntervalSince1970: 1_754_006_400) // 2025-08-01
        let item = try RecurringItem(
            name: "Streaming",
            amount: Money(amount: 199, currency: .mxn),
            kind: .expense,
            dayOfMonth: 3,
            paymentMethod: .credit(cardID: cardID),
            lastRegisteredMonth: monthStart)

        try await store.save(item)
        let results = try await store.items()

        #expect(results.first?.paymentMethod == .credit(cardID: cardID))
        #expect(results.first?.lastRegisteredMonth == monthStart)
    }

    @Test("El mes del registro automático hace round-trip")
    func mesDelRegistroAutomaticoHaceRoundTrip() async throws {
        let store = try await makeStore()
        let monthStart = Date(timeIntervalSince1970: 1_754_006_400) // 2025-08-01
        let item = try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 15000, currency: .mxn),
            kind: .income,
            dayOfMonth: 15,
            lastAutoRegisteredMonth: monthStart)

        try await store.save(item)
        let results = try await store.items()

        #expect(results.first?.lastAutoRegisteredMonth == monthStart)
    }

    @Test("Un movimiento guarda de qué recurrente salió, también después de corregirlo")
    func movimientoGuardaSuRecurrente() async throws {
        let store = try await makeStore()
        let itemID = RecurringItemID()
        var expense = Expense(
            kind: .income,
            amount: Money(amount: 15000, currency: .mxn),
            concept: "Sueldo",
            date: Date(timeIntervalSince1970: 1_755_216_000),
            recurringItemID: itemID)
        try await store.save(expense)

        expense.amount = Money(amount: 15500, currency: .mxn)
        try await store.save(expense)

        let results = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(results.count == 1)
        #expect(results.first?.recurringItemID == itemID)
        #expect(results.first?.amount.amount == 15500)
    }

    @Test("Borrar quita el recurrente del store")
    func recurrenteBorrarLoQuita() async throws {
        let store = try await makeStore()
        let item = try RecurringItem(name: "Renta", amount: .zero(.mxn), kind: .expense, dayOfMonth: 5)
        try await store.save(item)
        try await store.delete(id: item.id)

        let results = try await store.items()
        #expect(results.isEmpty)
    }
}

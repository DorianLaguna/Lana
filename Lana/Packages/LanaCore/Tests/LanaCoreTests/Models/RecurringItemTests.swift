import Foundation
import Testing
@testable import LanaCore

@Suite("RecurringItem")
struct RecurringItemTests {
    @Test("Un ítem válido se crea sin problema")
    func itemValido() throws {
        let item = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 8000, currency: .mxn),
            kind: .expense,
            category: "hogar",
            dayOfMonth: 5)
        #expect(item.name == "Renta")
        #expect(item.category == "hogar")
    }

    @Test("Nombre vacío truena")
    func nombreVacioTruena() {
        #expect(throws: RecurringItemError.self) {
            _ = try RecurringItem(name: "  ", amount: .zero(.mxn), kind: .expense, dayOfMonth: 5)
        }
    }

    @Test("Día fuera de 1-31 truena")
    func diaInvalidoTruena() {
        #expect(throws: RecurringItemError.self) {
            _ = try RecurringItem(name: "Renta", amount: .zero(.mxn), kind: .expense, dayOfMonth: 32)
        }
    }

    @Test("Un ingreso sí lleva categoría — un sueldo puede decir que es sueldo (ADR-0040)")
    func ingresoLlevaCategoria() throws {
        let item = try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 15000, currency: .mxn),
            kind: .income,
            category: IncomeCategory.sueldo.rawValue,
            dayOfMonth: 15)
        #expect(item.category == "sueldo")
    }

    @Test("Un gasto puede llevar subcategoría")
    func gastoPuedeLlevarSubcategoria() throws {
        let item = try RecurringItem(
            name: "Streaming",
            amount: Money(amount: 199, currency: .mxn),
            kind: .expense,
            category: "entretenimiento",
            subcategory: "suscripciones",
            dayOfMonth: 3)
        #expect(item.subcategory == "suscripciones")
    }

    @Test("Un ingreso sí lleva subcategoría")
    func ingresoLlevaSubcategoria() throws {
        let item = try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 15000, currency: .mxn),
            kind: .income,
            subcategory: "quincena",
            dayOfMonth: 15)
        #expect(item.subcategory == "quincena")
    }

    @Test("Un ingreso sigue sin método de pago — no se paga con nada")
    func ingresoSigueSinMetodoDePago() throws {
        let item = try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 15000, currency: .mxn),
            kind: .income,
            dayOfMonth: 15,
            paymentMethod: .cash)
        #expect(item.paymentMethod == nil)
    }
}

@Suite("RecurringItem — registro en el mes (ADR-0042)")
struct RecurringItemRegistrationTests {
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

    private func salary(day: Int = 15) throws -> RecurringItem {
        try RecurringItem(name: "Sueldo", amount: Money(amount: 15000, currency: .mxn), kind: .income, dayOfMonth: day)
    }

    @Test("Un movimiento ligado en el mes lo marca como registrado")
    func movimientoLigadoLoMarca() throws {
        let item = try salary()
        let expense = Expense(
            kind: .income,
            amount: item.amount,
            concept: "Sueldo",
            date: date(2026, 9, 10),
            recurringItemID: item.id)

        #expect(item.registration(in: [expense], forMonthOf: date(2026, 9, 15), calendar: calendar) == .linked(expense))
    }

    @Test("Sin movimiento, o con uno de otro mes u otro recurrente, sigue pendiente")
    func sinMovimientoSiguePendiente() throws {
        let item = try salary()
        let otherMonth = Expense(
            kind: .income,
            amount: item.amount,
            concept: "Sueldo",
            date: date(2026, 8, 15),
            recurringItemID: item.id)
        let otherItem = Expense(
            kind: .income,
            amount: item.amount,
            concept: "Sueldo",
            date: date(2026, 9, 15),
            recurringItemID: RecurringItemID())
        let unlinked = Expense(kind: .income, amount: item.amount, concept: "Sueldo", date: date(2026, 9, 15))

        let registration = item.registration(
            in: [otherMonth, otherItem, unlinked],
            forMonthOf: date(2026, 9, 15),
            calendar: calendar)
        #expect(registration == nil)
    }

    @Test("La marca heredada sigue contando como registrado en su mes")
    func marcaHeredadaCuenta() throws {
        var item = try salary()
        item.lastRegisteredMonth = date(2026, 9, 1)

        #expect(item.registration(in: [], forMonthOf: date(2026, 9, 20), calendar: calendar) == .legacy)
        #expect(item.registration(in: [], forMonthOf: date(2026, 10, 20), calendar: calendar) == nil)
    }

    @Test("Un recurrente del 31 vence el 30 en septiembre")
    func elTreintaYUnoVenceElTreintaEnSeptiembre() throws {
        let item = try salary(day: 31)

        #expect(!item.isDue(asOf: date(2026, 9, 29), calendar: calendar))
        #expect(item.isDue(asOf: date(2026, 9, 30), calendar: calendar))
    }

    @Test("El movimiento conserva su recurrente tras corregirse, y al anularse deja de contar")
    func elVinculoSobreviveCorreccionYAnulacion() throws {
        let item = try salary()
        let added = IncomeAdded(
            amount: item.amount,
            concept: "Sueldo",
            date: date(2026, 9, 15),
            recurringItemID: item.id)
        let corrected = ExpenseCorrected(correctsEventID: added.id, amount: Money(amount: 15500, currency: .mxn))

        let afterCorrection = ExpenseProjection.expenses(from: [.incomeAdded(added), .expenseCorrected(corrected)])
        #expect(afterCorrection.first?.recurringItemID == item.id)

        let voided = ExpenseVoided(voidsEventID: added.id)
        let afterVoid = ExpenseProjection.expenses(
            from: [.incomeAdded(added), .expenseCorrected(corrected), .expenseVoided(voided)])
        #expect(item.registration(in: afterVoid, forMonthOf: date(2026, 9, 15), calendar: calendar) == nil)
    }
}

@Suite("InMemoryRecurringItemStore")
struct RecurringItemStoreTests {
    @Test("Guardar y leer ítems, ordenados por día del mes")
    func guardarYLeerOrdenadosPorDia() async throws {
        let store = InMemoryRecurringItemStore()
        let renta = try RecurringItem(name: "Renta", amount: .zero(.mxn), kind: .expense, dayOfMonth: 5)
        let sueldo = try RecurringItem(name: "Sueldo", amount: .zero(.mxn), kind: .income, dayOfMonth: 15)
        try await store.save(sueldo)
        try await store.save(renta)

        let items = try await store.items()
        #expect(items.map(\.name) == ["Renta", "Sueldo"])
    }

    @Test("Guardar de nuevo el mismo ítem lo reemplaza, no lo duplica")
    func guardarDeNuevoReemplaza() async throws {
        let store = InMemoryRecurringItemStore()
        var item = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 8000, currency: .mxn),
            kind: .expense,
            dayOfMonth: 5)
        try await store.save(item)

        item.amount = Money(amount: 8500, currency: .mxn)
        try await store.save(item)

        let items = try await store.items()
        #expect(items.count == 1)
        #expect(items.first?.amount.amount == 8500)
    }

    @Test("Borrar quita el ítem del store")
    func borrarQuitaElItem() async throws {
        let store = InMemoryRecurringItemStore()
        let item = try RecurringItem(name: "Renta", amount: .zero(.mxn), kind: .expense, dayOfMonth: 5)
        try await store.save(item)
        try await store.delete(id: item.id)

        let items = try await store.items()
        #expect(items.isEmpty)
    }
}

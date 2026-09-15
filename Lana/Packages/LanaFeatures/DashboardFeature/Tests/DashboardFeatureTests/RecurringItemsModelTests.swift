import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("RecurringItemsModel")
@MainActor
struct RecurringItemsModelTests {
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

    @Test("onAppear carga los ítems guardados")
    func onAppearCargaLosItems() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let item = try RecurringItem(name: "Renta", amount: .zero(.mxn), kind: .expense, dayOfMonth: 5)
        try await recurringItemStore.save(item)

        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore())
        await model.onAppear()

        #expect(model.items.map(\.id) == [item.id])
    }

    @Test("Registrar un recurrente lo guarda como un gasto normal")
    func registrarUnRecurrenteLoGuardaComoGastoNormal() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let item = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 8000, currency: .mxn),
            kind: .expense,
            category: "hogar",
            dayOfMonth: 5)
        try await recurringItemStore.save(item)

        let store = InMemoryExpenseStore()
        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: store,
            cardStore: InMemoryCardStore())
        await model.onAppear()
        try await model.register(item)

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.count == 1)
        #expect(saved.first?.concept == "Renta")
        #expect(saved.first?.amount.amount == 8000)
        #expect(saved.first?.needsReview == false)
    }

    @Test("Registrar un recurrente conserva su subcategoría en el gasto")
    func registrarUnRecurrenteConservaSuSubcategoria() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let item = try RecurringItem(
            name: "Streaming",
            amount: Money(amount: 199, currency: .mxn),
            kind: .expense,
            category: "entretenimiento",
            subcategory: "suscripciones",
            dayOfMonth: 3)
        try await recurringItemStore.save(item)

        let store = InMemoryExpenseStore()
        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: store,
            cardStore: InMemoryCardStore())
        await model.onAppear()
        try await model.register(item)

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.first?.subcategory == "suscripciones")
    }

    @Test("Registrar un recurrente dos veces crea dos gastos — no hay deduplicado silencioso")
    func registrarDosVecesCreaDosGastos() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let item = try RecurringItem(
            name: "Café",
            amount: Money(amount: 50, currency: .mxn),
            kind: .expense,
            dayOfMonth: 1)
        try await recurringItemStore.save(item)

        let store = InMemoryExpenseStore()
        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: store,
            cardStore: InMemoryCardStore())
        try await model.register(item)
        try await model.register(item)

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.count == 2)
    }

    @Test("registerDueItems registra automáticamente lo vencido, ya confirmado — no hay nada que revisar")
    func registerDueItemsRegistraLoVencido() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let item = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 8000, currency: .mxn),
            kind: .expense,
            category: "hogar",
            dayOfMonth: 5)
        try await recurringItemStore.save(item)

        let store = InMemoryExpenseStore()
        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: store,
            cardStore: InMemoryCardStore())
        await model.onAppear()
        await model.registerDueItems(asOf: date(2026, 8, 10), calendar: calendar)

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.count == 1)
        #expect(saved.first?.needsReview == false)
    }

    @Test("registerDueItems no toca lo que todavía no vence este mes")
    func registerDueItemsNoTocaLoQueNoVence() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let item = try RecurringItem(name: "Renta", amount: .zero(.mxn), kind: .expense, dayOfMonth: 20)
        try await recurringItemStore.save(item)

        let store = InMemoryExpenseStore()
        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: store,
            cardStore: InMemoryCardStore())
        await model.onAppear()
        await model.registerDueItems(asOf: date(2026, 8, 10), calendar: calendar)

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.isEmpty)
    }

    @Test("registerDueItems no duplica lo que ya se registró este mes, manual o automático")
    func registerDueItemsNoDuplicaLoYaRegistrado() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let item = try RecurringItem(name: "Renta", amount: .zero(.mxn), kind: .expense, dayOfMonth: 5)
        try await recurringItemStore.save(item)

        let store = InMemoryExpenseStore()
        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: store,
            cardStore: InMemoryCardStore())
        await model.onAppear()
        try await model.register(item, on: date(2026, 8, 7))
        await model.registerDueItems(asOf: date(2026, 8, 10), calendar: calendar)

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.count == 1)
    }

    @Test("Subir el monto de un recurrente no reescribe lo ya registrado — garantía de versión")
    func subirElMontoNoReescribeLoYaRegistrado() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        var item = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 8000, currency: .mxn),
            kind: .expense,
            dayOfMonth: 5)
        try await recurringItemStore.save(item)

        let store = InMemoryExpenseStore()
        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: store,
            cardStore: InMemoryCardStore())
        await model.onAppear()
        try await model.register(item, on: date(2026, 8, 5))

        // Sube la renta el mes siguiente — mismo id, solo cambia el monto.
        item.amount = Money(amount: 9000, currency: .mxn)
        try await model.save(item)

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.count == 1)
        #expect(saved.first?.amount.amount == 8000)
    }

    @Test("Borrar un recurrente lo quita de la lista")
    func borrarUnRecurrenteLoQuitaDeLaLista() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let item = try RecurringItem(name: "Renta", amount: .zero(.mxn), kind: .expense, dayOfMonth: 5)
        try await recurringItemStore.save(item)

        let model = RecurringItemsModel(
            recurringItemStore: recurringItemStore,
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore())
        await model.onAppear()
        try await model.delete(item)

        #expect(model.items.isEmpty)
    }
}

@Suite("AddRecurringItemModel")
@MainActor
struct AddRecurringItemModelTests {
    @Test("Guardar un ítem válido lo persiste en el store")
    func guardarUnItemValidoLoPersiste() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let model = AddRecurringItemModel(recurringItemStore: recurringItemStore, store: InMemoryExpenseStore())
        model.name = "Renta"
        model.amount = 8000
        model.kind = .expense
        model.category = "hogar"
        model.dayOfMonth = 5

        let saved = await model.save()

        #expect(saved)
        let items = try await recurringItemStore.items()
        #expect(items.count == 1)
        #expect(items.first?.name == "Renta")
    }

    @Test("Nombre vacío no guarda y deja ver el error")
    func nombreVacioNoGuarda() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let model = AddRecurringItemModel(recurringItemStore: recurringItemStore, store: InMemoryExpenseStore())
        model.name = "  "
        model.amount = 100

        let saved = await model.save()

        #expect(!saved)
        #expect(model.errorMessage != nil)
        let items = try await recurringItemStore.items()
        #expect(items.isEmpty)
    }

    @Test("Editar un ítem existente conserva su id")
    func editarUnItemExistenteConservaSuId() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let existing = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 8000, currency: .mxn),
            kind: .expense,
            dayOfMonth: 5)
        try await recurringItemStore.save(existing)

        let model = AddRecurringItemModel(
            recurringItemStore: recurringItemStore,
            store: InMemoryExpenseStore(),
            editing: existing)
        model.amount = 8500
        _ = await model.save()

        let items = try await recurringItemStore.items()
        #expect(items.count == 1)
        #expect(items.first?.id == existing.id)
        #expect(items.first?.amount.amount == 8500)
    }

    @Test("Guardar un ítem con subcategoría la persiste")
    func guardarUnItemConSubcategoriaLaPersiste() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let model = AddRecurringItemModel(recurringItemStore: recurringItemStore, store: InMemoryExpenseStore())
        model.name = "Streaming"
        model.amount = 199
        model.kind = .expense
        model.category = "entretenimiento"
        model.subcategory = "suscripciones"
        model.dayOfMonth = 3

        _ = await model.save()

        let items = try await recurringItemStore.items()
        #expect(items.first?.subcategory == "suscripciones")
    }

    @Test("Un ingreso recurrente guarda su categoría — un sueldo dice que es sueldo (ADR-0040)")
    func unIngresoNoLlevaCategoria() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let model = AddRecurringItemModel(recurringItemStore: recurringItemStore, store: InMemoryExpenseStore())
        model.name = "Sueldo"
        model.amount = 15000
        model.kind = .income
        model.category = IncomeCategory.sueldo.rawValue
        model.dayOfMonth = 15

        _ = await model.save()

        let items = try await recurringItemStore.items()
        #expect(items.first?.category == "sueldo")
    }

    @Test("Un gasto guarda con qué se paga, incluyendo transferencia")
    func unGastoGuardaConQueSePaga() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let model = AddRecurringItemModel(recurringItemStore: recurringItemStore, store: InMemoryExpenseStore())
        model.name = "Streaming"
        model.amount = 199
        model.kind = .expense
        model.dayOfMonth = 3
        model.paymentMethod = .transfer

        _ = await model.save()

        let items = try await recurringItemStore.items()
        #expect(items.first?.paymentMethod == .transfer)
    }

    @Test("Un ingreso nunca guarda con qué se paga, aunque el formulario tenga uno elegido")
    func unIngresoNuncaGuardaConQueSePaga() async throws {
        let recurringItemStore = InMemoryRecurringItemStore()
        let model = AddRecurringItemModel(recurringItemStore: recurringItemStore, store: InMemoryExpenseStore())
        model.name = "Sueldo"
        model.amount = 15000
        model.kind = .income
        model.dayOfMonth = 15
        model.paymentMethod = .transfer

        _ = await model.save()

        let items = try await recurringItemStore.items()
        #expect(items.first?.paymentMethod == nil)
    }
}

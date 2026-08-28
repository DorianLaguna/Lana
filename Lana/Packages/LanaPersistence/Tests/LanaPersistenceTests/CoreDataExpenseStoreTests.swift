import CoreData
import Foundation
import LanaCore
import Testing
@testable import LanaPersistence

// .serialized: cada test crea su propio NSManagedObjectModel/NSPersistentContainer;
// correrlos en paralelo hizo crashear el proceso de forma intermitente (Core
// Data confunde su registro de NSManagedObject → entidad entre containers
// concurrentes — ver nota en Docs/PLAN.md Fase 2).
@Suite("CoreDataExpenseStore", .serialized)
struct CoreDataExpenseStoreTests {
    /// `internal`, no `private` — `CoreDataRecurringItemStoreTests.swift`
    /// extiende este mismo tipo (mismo `@Suite(.serialized)`, evita repetir
    /// el crash de containers concurrentes de la nota de arriba) desde otro
    /// archivo, y `private` es de alcance por archivo.
    func makeStore() async throws -> CoreDataExpenseStore {
        try await CoreDataExpenseStore(inMemory: true)
    }

    func fullRange() -> DateInterval {
        DateInterval(start: .distantPast, end: .distantFuture)
    }

    @Test("Guardar y leer un gasto hace round-trip completo")
    func guardarYLeerHaceRoundTrip() async throws {
        let store = try await makeStore()
        let expense = Expense(
            kind: .expense,
            amount: Money(amount: 150, currency: .mxn),
            concept: "café",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000))

        try await store.save(expense)
        let results = try await store.expenses(in: fullRange())

        #expect(results.count == 1)
        #expect(results.first?.id == expense.id)
        #expect(results.first?.concept == "café")
        #expect(results.first?.category == "comida")
        #expect(results.first?.amount == expense.amount)
    }

    @Test("La subcategoría hace round-trip — se perdía antes de este fix")
    func subcategoriaHaceRoundTrip() async throws {
        let store = try await makeStore()
        let expense = Expense(
            kind: .expense,
            amount: Money(amount: 1010, currency: .mxn),
            concept: "gasolina",
            category: "transporte",
            subcategory: "gasolina",
            date: Date(timeIntervalSince1970: 1_700_000_000))

        try await store.save(expense)
        let results = try await store.expenses(in: fullRange())

        #expect(results.first?.subcategory == "gasolina")
    }

    @Test("Guardar dos veces el mismo id corrige, no duplica")
    func guardarDosVecesCorrige() async throws {
        let store = try await makeStore()
        var expense = Expense(
            kind: .expense,
            amount: Money(amount: 100, currency: .mxn),
            concept: "café",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000))
        try await store.save(expense)

        expense.amount = Money(amount: 120, currency: .mxn)
        expense.concept = "café con Ana"
        try await store.save(expense)

        let results = try await store.expenses(in: fullRange())
        #expect(results.count == 1)
        #expect(results.first?.amount.amount == 120)
        #expect(results.first?.concept == "café con Ana")
    }

    @Test("Borrar anula el gasto — no aparece más en las lecturas")
    func borrarAnulaElGasto() async throws {
        let store = try await makeStore()
        let expense = Expense(
            kind: .expense,
            amount: Money(amount: 100, currency: .mxn),
            concept: "café",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000))
        try await store.save(expense)
        try await store.delete(id: expense.id)

        let results = try await store.expenses(in: fullRange())
        #expect(results.isEmpty)
    }

    @Test("expenses(in:) filtra por rango de fechas")
    func expensesFiltraPorRango() async throws {
        let store = try await makeStore()
        let dentro = Expense(
            kind: .expense,
            amount: Money(amount: 100, currency: .mxn),
            concept: "dentro del rango",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000))
        let fuera = Expense(
            kind: .expense,
            amount: Money(amount: 100, currency: .mxn),
            concept: "fuera del rango",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_800_000_000))
        try await store.save(dentro)
        try await store.save(fuera)

        let range = DateInterval(
            start: Date(timeIntervalSince1970: 1_699_000_000),
            end: Date(timeIntervalSince1970: 1_701_000_000))
        let results = try await store.expenses(in: range)

        #expect(results.map(\.id) == [dentro.id])
    }

    @Test("Un ingreso hace round-trip sin categoría")
    func ingresoHaceRoundTripSinCategoria() async throws {
        let store = try await makeStore()
        let income = Expense(
            kind: .income,
            amount: Money(amount: 5000, currency: .mxn),
            concept: "nómina",
            date: Date(timeIntervalSince1970: 1_700_000_000))
        try await store.save(income)

        let results = try await store.expenses(in: fullRange())
        #expect(results.first?.kind == .income)
        #expect(results.first?.category == nil)
    }

    @Test("Dos stores distintos sobre el mismo archivo persisten en disco")
    func persisteEnDiscoEntreInstancias() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let expense = Expense(
            kind: .expense,
            amount: Money(amount: 100, currency: .mxn),
            concept: "café",
            category: "comida",
            date: Date(timeIntervalSince1970: 1_700_000_000))

        let store = try await CoreDataExpenseStore(storeURL: fileURL)
        try await store.save(expense)
        try await store.close()

        let reopened = try await CoreDataExpenseStore(storeURL: fileURL)
        let results = try await reopened.expenses(in: fullRange())
        #expect(results.count == 1)
        #expect(results.first?.concept == "café")
    }

    // No hay test de `.live(cloudKitContainerIdentifier:)` con un identificador
    // real: configurar `cloudKitContainerOptions` sin los entitlements de una
    // app firmada (push notifications, contenedor de iCloud provisionado)
    // crashea el proceso — se comprobó al escribir esta suite. Coincide con
    // lo que ya dice ADR-0004: CloudKit real solo se prueba en un device
    // físico dentro de la app. El camino local (`cloudKitContainerIdentifier:
    // nil`, todos los tests de arriba) sí se prueba aquí sin riesgo.

    /// Valida que el esquema soporta el patrón "una zona por lista compartida"
    /// (Docs/.claude/skills/cloudkit-sharing): compartir una `CDSharedList` via
    /// `NSPersistentCloudKitContainer.share(_:to:)` mueve, junto con ella, todos
    /// sus `CDEvent` relacionados a la zona nueva del share — porque son parte
    /// del mismo grafo de objetos. Esto solo prueba que el grafo está bien
    /// armado; el share real requiere una cuenta de iCloud y dos devices
    /// físicos (ADR-0004), fuera de alcance hasta la Fase 8. Vive en esta
    /// misma suite (no una aparte) para quedar bajo el mismo `.serialized`.
    @Test("Un evento relacionado con una lista viaja con ella en el mismo grafo")
    func eventoViajaConSuLista() throws {
        let model = LanaManagedObjectModel.make()
        let container = NSPersistentContainer(name: "test", managedObjectModel: model)
        let description = container.persistentStoreDescriptions[0]
        description.url = URL(fileURLWithPath: "/dev/null")

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        #expect(loadError == nil)

        let context = container.viewContext
        let list = CDSharedList(context: context)
        list.id = UUID()
        list.name = "Casa"

        let event = CDEvent(context: context)
        event.id = UUID()
        event.kind = "expenseAdded"
        event.sharedList = list

        try context.save()

        #expect(list.events?.count == 1)
        #expect((list.events?.anyObject() as? CDEvent)?.id == event.id)
    }

    // MARK: - CardStore (ADR-0014, mismo container que ExpenseStore)

    @Test("Guardar y leer una tarjeta hace round-trip completo")
    func tarjetaHaceRoundTrip() async throws {
        let store = try await makeStore()
        let card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)

        try await store.save(card)
        let results = try await store.cards()

        #expect(results.count == 1)
        #expect(results.first?.id == card.id)
        #expect(results.first?.alias == "BBVA Oro")
        #expect(results.first?.limit == card.limit)
    }

    @Test("El tipo y el color de la tarjeta hacen round-trip")
    func tarjetaTipoYColorHacenRoundTrip() async throws {
        let store = try await makeStore()
        let card = try Card(
            alias: "Nu débito",
            lastFourDigits: "1234",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5,
            kind: .debit,
            colorHex: "#6C4FB3")

        try await store.save(card)
        let results = try await store.cards()

        #expect(results.first?.kind == .debit)
        #expect(results.first?.colorHex == "#6C4FB3")
    }

    @Test("Guardar de nuevo la misma tarjeta la reemplaza, no la duplica")
    func tarjetaGuardarDeNuevoReemplaza() async throws {
        let store = try await makeStore()
        var card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await store.save(card)

        card.alias = "BBVA Platino"
        try await store.save(card)

        let results = try await store.cards()
        #expect(results.count == 1)
        #expect(results.first?.alias == "BBVA Platino")
    }

    @Test("Borrar quita la tarjeta del store")
    func tarjetaBorrarLaQuita() async throws {
        let store = try await makeStore()
        let card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await store.save(card)
        try await store.delete(id: card.id)

        let results = try await store.cards()
        #expect(results.isEmpty)
    }

    // MARK: - CorrectionVocabularyStore (ADR-0012, ADR-0014)

    @Test("Registrar un término hace round-trip completo")
    func vocabularioHaceRoundTrip() async throws {
        let store = try await makeStore()
        await store.record(term: "bocina", category: "ocio")

        let entries = await store.topEntries(limit: 10)
        #expect(entries.count == 1)
        #expect(entries.first?.term == "bocina")
        #expect(entries.first?.category == "ocio")
        #expect(entries.first?.useCount == 1)
    }

    @Test("Corregir el mismo término suma useCount en vez de duplicar")
    func vocabularioMismoTerminoSumaUseCount() async throws {
        let store = try await makeStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "Bocina", category: "ocio")
        await store.record(term: " bocina ", category: "ocio")

        let entries = await store.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.useCount == 3)
    }

    @Test("delete olvida solo el término indicado")
    func vocabularioDeleteOlvidaUnTermino() async throws {
        let store = try await makeStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "chicles", category: "despensa")

        await store.delete(term: "bocina")

        let entries = await store.allEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.term == "chicles")
    }

    @Test("deleteAll olvida todo el vocabulario")
    func vocabularioDeleteAllOlvidaTodo() async throws {
        let store = try await makeStore()
        await store.record(term: "bocina", category: "ocio")
        await store.record(term: "chicles", category: "despensa")

        await store.deleteAll()

        let entries = await store.allEntries()
        #expect(entries.isEmpty)
    }
}

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

    @Test("Un ingreso nunca lleva categoría, aunque se pase una")
    func ingresoNuncaLlevaCategoria() throws {
        let item = try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 15000, currency: .mxn),
            kind: .income,
            category: "otro",
            dayOfMonth: 15)
        #expect(item.category == nil)
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

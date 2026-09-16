import Foundation
import Testing
@testable import LanaCore

/// El texto **exacto** que devuelven las herramientas.
///
/// Aparte de `LedgerToolboxTests`, que cuida que las cifras estén bien, este
/// archivo cuida que el texto no se mueva. La distinción importa: ese texto es
/// lo que recibe el modelo para narrar y lo que ve quien toca un chip
/// (`QuickAnswer`), y las pruebas de cifras usan `contains`, así que el formato
/// podía desviarse —o volver a salir en inglés— sin que fallara nada.
///
/// Si una de estas truena, la pregunta no es "¿arreglo el test?" sino "¿de
/// verdad quise cambiar lo que lee el modelo?".
@Suite("LedgerToolbox — el texto que se entrega")
struct LedgerToolboxTextTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    private func toolbox(
        _ store: InMemoryExpenseStore,
        cards: [Card] = [],
        recurringItems: [RecurringItem] = []) -> LedgerToolbox {
        LedgerToolbox(
            store: store,
            sharedListStore: InMemorySharedListStore(),
            cardStore: InMemoryCardStore(seed: cards),
            cardPaymentStore: InMemoryCardPaymentStore(),
            recurringItemStore: InMemoryRecurringItemStore(seed: recurringItems),
            calendar: calendar)
    }

    private func expense(_ amount: Decimal, _ concept: String, _ category: String, on date: Date) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: concept,
            category: category,
            date: date)
    }

    @Test("El desglose por categoría se entrega tal cual, con el mes en español")
    func elDesglosePorCategoria() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 300, currency: .mxn),
            concept: "súper",
            category: "despensa",
            date: date(2026, 9, 15)))

        let answer = await toolbox(store).totalPorCategoria(year: 2026, month: 9)

        #expect(answer == """
        Septiembre 2026, en MXN: $300.00 en total.
          despensa: $300.00
        """)
    }

    @Test("El origen del ingreso se entrega tal cual")
    func elOrigenDelIngreso() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .income,
            amount: Money(amount: 18000, currency: .mxn),
            concept: "quincena",
            category: IncomeCategory.sueldo.rawValue,
            date: date(2026, 9, 15)))

        let answer = await toolbox(store).origenDelIngreso(year: 2026, month: 9)

        #expect(answer == """
        Septiembre 2026, en MXN: entraron $18,000.00.
          sueldo: $18,000.00
        """)
    }

    @Test("Una fecha suelta dentro de una respuesta va en español")
    func laFechaDentroDeUnaRespuesta() throws {
        #expect(try LedgerToolbox.day(date(2026, 9, 15)) == "15 de septiembre")
    }

    @Test("La comparación entre meses nombra los dos meses en español")
    func laComparacionEntreMeses() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(1000, "renta", "hogar", on: date(2026, 8, 5)))
        try await store.save(expense(1500, "renta", "hogar", on: date(2026, 9, 5)))
        try await store.save(expense(120, "café", "comida", on: date(2026, 9, 7)))

        let answer = await toolbox(store).comparaMeses(yearA: 2026, monthA: 9, yearB: 2026, monthB: 8)

        #expect(answer == """
        En MXN, Septiembre 2026 subió $620.00 contra Agosto 2026.
          hogar: subió $500.00
          comida: subió $120.00
        """)
    }

    @Test("Los mayores gastos se entregan de mayor a menor, con su concepto")
    func losMayoresGastos() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(1500, "renta", "hogar", on: date(2026, 9, 5)))
        try await store.save(expense(120, "café", "comida", on: date(2026, 9, 7)))

        let answer = await toolbox(store).mayoresGastos(year: 2026, month: 9)

        #expect(answer == """
        Los gastos más grandes de Septiembre 2026:
          renta: $1,500.00
          café: $120.00
        """)
    }

    @Test("La deuda por tarjeta separa lo ya facturado de lo del ciclo abierto")
    func laDeudaPorTarjeta() async throws {
        let card = try Card(
            alias: "Nu",
            lastFourDigits: "1234",
            limit: Money(amount: 30000, currency: .mxn),
            cutoffDay: 10,
            dueDay: 20,
            kind: .credit)

        let answer = try await toolbox(InMemoryExpenseStore(), cards: [card])
            .deudaPorTarjeta(asOf: date(2026, 9, 18))

        #expect(answer == """
        Deuda por tarjeta:
          Nu: $0.00 ya facturado y pendiente, más $0.00 acumulado en el ciclo abierto
        """)
    }

    @Test("El disponible dice el periodo, de qué está hecho y que no viene del banco")
    func elDisponibleProyectado() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .income,
            amount: Money(amount: 18000, currency: .mxn),
            concept: "sueldo",
            date: date(2026, 9, 15)))
        let sueldo = try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 18000, currency: .mxn),
            kind: .income,
            dayOfMonth: 15)

        let answer = try await toolbox(store, recurringItems: [sueldo])
            .disponibleProyectado(asOf: date(2026, 9, 18))

        #expect(answer == """
        En MXN, del 15 de septiembre al 14 de octubre:
        Entró $18,000.00 y salió $0.00, así que ahora traes $18,000.00.
        No falta ningún pago con fecha.
        Disponible al final del periodo: $18,000.00.
        Va de tu último sueldo al siguiente. Sale de lo que registraste en Lana, no de tu banco.
        """)
    }
}

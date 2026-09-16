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

    private func toolbox(_ store: InMemoryExpenseStore) -> LedgerToolbox {
        LedgerToolbox(
            store: store,
            sharedListStore: InMemorySharedListStore(),
            cardStore: InMemoryCardStore(),
            cardPaymentStore: InMemoryCardPaymentStore(),
            recurringItemStore: InMemoryRecurringItemStore(),
            calendar: calendar)
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
}

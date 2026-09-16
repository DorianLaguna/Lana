import Foundation
import Testing
@testable import LanaCore

@Suite("Preguntas de un toque, sin modelo")
struct QuickAnswerTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func toolbox(
        expenses: [Expense] = [],
        cards: [Card] = [],
        recurringItems: [RecurringItem] = []) -> LedgerToolbox {
        LedgerToolbox(
            store: InMemoryExpenseStore(seed: expenses),
            sharedListStore: InMemorySharedListStore(),
            cardStore: InMemoryCardStore(seed: cards),
            cardPaymentStore: InMemoryCardPaymentStore(),
            recurringItemStore: InMemoryRecurringItemStore(seed: recurringItems),
            calendar: calendar)
    }

    private func expense(_ amount: Decimal, category: String, day: Int) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: "algo",
            category: category,
            // swiftlint:disable:next force_unwrapping
            date: calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!)
    }

    @Test("Viendo un mes se ofrecen las seis")
    func seisEnUnMes() {
        #expect(QuickAnswer.available(for: QueryPeriod(year: 2026, month: 9)).count == 6)
    }

    @Test("Viendo el año solo se ofrecen las que no dependen de un mes")
    func soloLasDelAnio() {
        let offered = QuickAnswer.available(for: QueryPeriod(year: 2026))

        #expect(offered == [.deudaDeTarjetas, .cuantoQueda])
    }

    @Test("Enero tiene detrás diciembre del año anterior, no el mes cero")
    func eneroCruzaElAnio() {
        let previous = QuickAnswer.previousMonth(year: 2026, month: 1, calendar: calendar)

        #expect(previous.year == 2025)
        #expect(previous.month == 12)
    }

    @Test("Un chip contesta con cifras reales, sin pasar por ningún modelo")
    func contestaConCifras() async {
        let box = toolbox(expenses: [
            expense(300, category: "despensa", day: 2),
            expense(120, category: "transporte", day: 3)
        ])

        let answer = await QuickAnswer.enQueSeFue.answer(
            using: box,
            viewing: QueryPeriod(year: 2026, month: 9),
            calendar: calendar)

        #expect(answer.contains("despensa"))
        #expect(answer.contains("420"))
    }

    @Test("Sin tarjetas de crédito lo dice, en vez de devolver una cifra vacía")
    func sinTarjetas() async {
        let answer = await QuickAnswer.deudaDeTarjetas.answer(
            using: toolbox(),
            viewing: QueryPeriod(year: 2026, month: 9),
            calendar: calendar)

        #expect(answer == "No hay tarjetas de crédito registradas.")
    }

    @Test("Los títulos no dicen «este mes»: la respuesta sale del periodo que se está viendo")
    func titulosSinMes() {
        for answer in QuickAnswer.allCases {
            #expect(!answer.title.contains("este mes"))
        }
    }
}

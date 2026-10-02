import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("Mes — día a día")
struct DailySpendingTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ month: Int, _ day: Int) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func expense(_ amount: Decimal, month: Int, day: Int, recurring: Bool = false) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: "algo",
            date: date(month, day),
            recurringItemID: recurring ? RecurringItemID() : nil)
    }

    private func make(
        _ current: [Expense],
        _ previous: [Expense],
        month: Int = 10,
        asOf: Date,
        excludingRecurring: Bool = false,
        recurring: DailySpending.RecurringByCut = .init()) throws -> DailySpending {
        let data = DailySpending.make(
            current: current,
            previous: previous,
            request: .init(
                month: date(month, 1),
                currency: .mxn,
                asOf: asOf,
                excludingRecurring: excludingRecurring,
                recurring: recurring),
            amount: { $0.amount.amount },
            calendar: calendar)
        return try #require(data)
    }

    @Test("A media quincena: cada día, lo acumulado hasta hoy y el día más caro")
    func aMedioMes() throws {
        let data = try make([
            expense(200, month: 10, day: 1),
            expense(1850, month: 10, day: 3),
            expense(150, month: 10, day: 3),
            expense(400, month: 10, day: 5),
            // Ingreso: no es gasto.
            Expense(kind: .income, amount: Money(amount: 12000, currency: .mxn), concept: "sueldo", date: date(10, 2))
        ], [], asOf: date(10, 5))

        #expect(data.lastDay == 5)
        #expect(data.daily.map(\.amount) == [200, 0, 2000, 0, 400])
        #expect(data.cumulative.map(\.amount) == [200, 200, 2200, 2200, 2600])
        #expect(data.peak?.day == 3)
        #expect(data.previousSpent(through: 5) == nil)
    }

    @Test("Se compara con el mismo día del mes anterior, recortado a su último día")
    func comparaAlMismoDia() throws {
        let data = try make(
            [expense(1000, month: 10, day: 2), expense(500, month: 10, day: 31)],
            [expense(700, month: 9, day: 1), expense(300, month: 9, day: 30)],
            asOf: date(11, 5))

        #expect(data.lastDay == 31)
        #expect(data.previousDaysInMonth == 30)
        #expect(data.previousSpent(through: 2) == 700)
        // El 31 de octubre contra el 30 de septiembre.
        #expect(data.previousSpent(through: 31) == 1000)
        #expect(data.spent(through: 31) == 1500)
    }

    @Test("Sin recurrentes deja fuera lo ligado a uno, en los dos meses")
    func sinRecurrentes() throws {
        let current = [expense(139, month: 10, day: 2, recurring: true), expense(300, month: 10, day: 2)]
        let previous = [expense(139, month: 9, day: 2, recurring: true), expense(50, month: 9, day: 3)]

        let all = try make(current, previous, asOf: date(10, 3))
        let chosen = try make(current, previous, asOf: date(10, 3), excludingRecurring: true)

        #expect(all.spent(through: 3) == 439)
        #expect(chosen.spent(through: 3) == 300)
        #expect(chosen.previousSpent(through: 3) == 50)
    }

    @Test("Tocar un día trae sus gastos, el más reciente primero y con el mismo filtro")
    @MainActor
    func gastosDeUnDia() async throws {
        let morning = Expense(
            kind: .expense, amount: Money(amount: 1850, currency: .mxn), concept: "Súper", date: date(9, 14))
        let night = Expense(
            kind: .expense,
            amount: Money(amount: 350, currency: .mxn),
            concept: "Tacos",
            date: date(9, 14).addingTimeInterval(8 * 3600))
        let model = DashboardModel(
            store: InMemoryExpenseStore(seed: [
                morning, night, expense(139, month: 9, day: 14, recurring: true), expense(90, month: 9, day: 15)
            ]),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore(),
            referenceDate: date(9, 20),
            calendar: calendar)
        await model.onAppear()

        #expect(model.expenses(onDay: 14, excludingRecurring: false).count == 3)
        #expect(model.expenses(onDay: 14, excludingRecurring: true).map(\.concept) == ["Tacos", "Súper"])
    }

    @Test("Lo recurrente cuenta por corte: lo de septiembre desde el día 1 y lo que se va a noviembre aparte")
    func recurrentesPorCorte() throws {
        let netflix = Commitment(concept: "Netflix", amount: Money(amount: -139, currency: .mxn), date: date(10, 11))
        let icloud = Commitment(concept: "iCloud", amount: Money(amount: -49, currency: .mxn), date: date(10, 28))
        let gamePass = expense(339, month: 10, day: 2, recurring: true)
        let afterCut = expense(209, month: 10, day: 4, recurring: true)
        let data = try make(
            [gamePass, afterCut, expense(500, month: 10, day: 3)],
            [],
            asOf: date(10, 5),
            recurring: .init(
                // El Netflix del 26 de septiembre, cobrado tras el corte.
                carriedIn: 139,
                countsNextMonth: { $0.id == afterCut.id },
                upcomingThisMonth: [netflix],
                upcomingNextMonth: [icloud]))

        #expect(data.recurringCumulative.map(\.amount) == [139, 478, 478, 478, 478])
        #expect(data.recurringSpent(through: 10) == 478)
        #expect(data.recurringSpent(through: 11) == 617)
        // Lo de noviembre empieza el día que tiene algo y no se suma arriba.
        #expect(data.nextMonthRecurringCumulative.first?.day == 4)
        #expect(data.nextMonthRecurringCumulative.first?.amount == 209)
        #expect(data.nextMonthRecurringCumulative.last?.amount == 258)
        #expect(data.upcomingNextMonthRecurring.map(\.concept) == ["iCloud"])
        #expect(data.recurringSpent(through: 31) == 617)
        // La línea de gasto sigue por fecha de compra.
        #expect(data.spent(through: 5) == 1048)
    }

    @Test("Sin recurrentes, o en un mes que ya pasó, no hay nada por caer")
    func sinPorCaer() throws {
        let netflix = Commitment(concept: "Netflix", amount: Money(amount: -139, currency: .mxn), date: date(10, 11))
        let filtered = try make(
            [expense(339, month: 10, day: 2, recurring: true)], [],
            asOf: date(10, 5), excludingRecurring: true,
            recurring: .init(carriedIn: 139, upcomingThisMonth: [netflix]))
        let past = try make(
            [expense(339, month: 10, day: 2, recurring: true)], [],
            asOf: date(11, 5), recurring: .init(upcomingThisMonth: [netflix]))

        #expect(filtered.recurringCumulative.isEmpty)
        #expect(filtered.upcomingRecurringCumulative.isEmpty)
        #expect(past.upcomingRecurringCumulative.isEmpty)
        #expect(past.recurringSpent(through: 31) == 339)
    }

    @Test("El eje dice miles con k y lo menor completo")
    func etiquetaDelEje() {
        #expect(DailySpendingSection.axisLabel(15000, currency: .mxn) == "$15k")
        #expect(DailySpendingSection.axisLabel(800, currency: .mxn) == "$800")
    }
}

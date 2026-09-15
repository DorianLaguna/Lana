import Foundation
import Testing
@testable import LanaCore

@Suite("AnnualStatistics")
struct AnnualStatisticsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func expense(
        kind: Expense.Kind = .expense,
        amount: Decimal,
        currency: Currency = .mxn,
        category: String? = "otro",
        subcategory: String? = nil,
        date: Date) -> Expense {
        Expense(
            kind: kind,
            amount: Money(amount: amount, currency: currency),
            concept: "algo",
            category: category,
            subcategory: subcategory,
            date: date)
    }

    @Test("La serie trae los doce meses, con los vacíos en cero")
    func laSerieTraeLosDoceMeses() throws {
        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: [expense(amount: 300, date: date(2026, 3, 10))],
            calendar: calendar,
            referenceDate: date(2026, 12, 31))

        let points = statistics.monthlyPoints(in: .mxn)
        #expect(points.count == 12)
        #expect(points[2].expenses == 300)
        #expect(points[2].hasActivity)
        #expect(points[0].expenses == 0)
        #expect(points[0].hasActivity == false)
    }

    @Test("Lo que cae fuera del año no entra, aunque se le pase")
    func loQueCaeFueraDelAnioNoEntra() throws {
        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: [
                expense(amount: 100, date: date(2026, 6, 1)),
                expense(amount: 999, date: date(2025, 6, 1))
            ],
            calendar: calendar,
            referenceDate: date(2026, 12, 31))

        #expect(statistics.period.total(in: .mxn)?.expenses == 100)
    }

    @Test("El 31 de diciembre y el 1 de enero no caen en el mismo año")
    func fronteraDeAnio() throws {
        let lastMoment = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 59, second: 59)))
        let expenses = try [
            expense(amount: 100, date: lastMoment),
            expense(amount: 200, date: date(2027, 1, 1))
        ]

        let year2026 = try AnnualStatistics(
            year: 2026, expenses: expenses, calendar: calendar, referenceDate: date(2027, 6, 1))
        let year2027 = try AnnualStatistics(
            year: 2027, expenses: expenses, calendar: calendar, referenceDate: date(2027, 6, 1))

        #expect(year2026.period.total(in: .mxn)?.expenses == 100)
        #expect(year2027.period.total(in: .mxn)?.expenses == 200)
    }

    @Test("En marzo el promedio divide entre 3, no entre 12")
    func enMarzoElPromedioDivideEntreTres() throws {
        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: [
                expense(amount: 300, date: date(2026, 1, 10)),
                expense(amount: 300, date: date(2026, 2, 10)),
                expense(amount: 300, date: date(2026, 3, 10))
            ],
            calendar: calendar,
            referenceDate: date(2026, 3, 15))

        #expect(statistics.monthsElapsed == 3)
        #expect(statistics.monthlyAverage(in: .mxn) == 300)
    }

    @Test("De un año ya pasado el promedio divide entre 12")
    func deUnAnioPasadoElPromedioDivideEntreDoce() throws {
        let statistics = try AnnualStatistics(
            year: 2025,
            expenses: [expense(amount: 1200, date: date(2025, 6, 10))],
            calendar: calendar,
            referenceDate: date(2026, 3, 15))

        #expect(statistics.monthsElapsed == 12)
        #expect(statistics.monthlyAverage(in: .mxn) == 100)
    }

    @Test("Un mes vacío no es el mes más barato — no se sabe nada de él")
    func unMesVacioNoEsElMesMasBarato() throws {
        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: [
                expense(amount: 500, date: date(2026, 1, 10)),
                expense(amount: 900, date: date(2026, 2, 10))
            ],
            calendar: calendar,
            referenceDate: date(2026, 12, 31))

        let extremes = try #require(statistics.extremes(in: .mxn))
        #expect(extremes.highest.expenses == 900)
        #expect(extremes.lowest.expenses == 500)
    }

    @Test("Un gasto chico y repetido es hormiga; uno grande y repetido no")
    func gastoHormiga() throws {
        // 12 000 al año / 12 meses = 1 000 de promedio mensual; el umbral es
        // el 5%, o sea 50.
        var expenses = (1 ... 6).compactMap { month in
            try? expense(amount: 1900, category: "hogar", subcategory: "renta", date: date(2026, month, 1))
        }
        expenses += (1 ... 6).compactMap { month in
            try? expense(amount: 40, category: "comida", subcategory: "café", date: date(2026, month, 2))
        }

        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: expenses,
            calendar: calendar,
            referenceDate: date(2026, 12, 31))

        let ants = statistics.antExpenses(in: .mxn)
        #expect(ants.map(\.label) == ["café"])
        #expect(ants.first?.count == 6)
        #expect(ants.first?.total == 240)
    }

    @Test("Un concepto que se repite pocas veces no es hormiga, por chico que sea")
    func pocasVecesNoEsHormiga() throws {
        let expenses = (1 ... 3).compactMap { month in
            try? expense(amount: 10, category: "comida", subcategory: "chicles", date: date(2026, month, 2))
        }

        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: expenses,
            calendar: calendar,
            referenceDate: date(2026, 12, 31))

        #expect(statistics.antExpenses(in: .mxn).isEmpty)
    }

    @Test("Los días con movimiento cuentan días distintos, no movimientos")
    func diasConMovimientoCuentanDiasDistintos() throws {
        let day = try date(2026, 1, 5)
        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: [
                expense(amount: 10, date: day),
                expense(amount: 20, date: day),
                expense(amount: 30, date: date(2026, 1, 6))
            ],
            calendar: calendar,
            referenceDate: date(2026, 1, 10))

        #expect(statistics.captureConsistency.daysWithActivity == 2)
        #expect(statistics.captureConsistency.daysElapsed == 10)
    }

    @Test("La racha más larga son días seguidos")
    func laRachaMasLargaSonDiasSeguidos() throws {
        let expenses = try [1, 2, 3, 7].map { day in
            try expense(amount: 10, date: date(2026, 1, day))
        }

        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: expenses,
            calendar: calendar,
            referenceDate: date(2026, 1, 10))

        #expect(statistics.captureConsistency.longestStreak == 3)
    }

    @Test("Un hoy todavía sin movimiento no rompe la racha viva")
    func unHoySinMovimientoNoRompeLaRacha() throws {
        let expenses = try [8, 9].map { day in
            try expense(amount: 10, date: date(2026, 1, day))
        }

        let statistics = try AnnualStatistics(
            year: 2026,
            expenses: expenses,
            calendar: calendar,
            referenceDate: date(2026, 1, 10))

        #expect(statistics.captureConsistency.currentStreak == 2)
    }

    @Test("Un año que todavía no empieza no tiene promedio")
    func unAnioQueNoEmpiezaNoTienePromedio() throws {
        let statistics = try AnnualStatistics(
            year: 2030,
            expenses: [],
            calendar: calendar,
            referenceDate: date(2026, 3, 15))

        #expect(statistics.monthsElapsed == 0)
        #expect(statistics.monthlyAverage(in: .mxn) == nil)
    }
}

import Foundation
import Testing
@testable import LanaCore

@Suite("PayPeriod")
struct PayPeriodTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func salary(on day: Int, name: String = "Sueldo") throws -> RecurringItem {
        try RecurringItem(
            name: name,
            amount: Money(amount: 18000, currency: .mxn),
            kind: .income,
            dayOfMonth: day)
    }

    @Test("Con sueldo quincenal, el periodo va del último sueldo al siguiente")
    func conSueldoQuincenalVaDeSueldoASueldo() throws {
        let items = try [salary(on: 15), salary(on: 30)]
        let period = try PayPeriod.current(for: date(2026, 3, 22), recurringItems: items, calendar: calendar)

        #expect(period.isAnchoredToIncome)
        #expect(try period.start == date(2026, 3, 15))
        #expect(try period.end == date(2026, 3, 30))
    }

    @Test("Cobrar el 15 no deja la segunda mitad del mes arrancando en ceros")
    func cobrarElQuinceCuentaParaLosDiasQueSiguen() throws {
        // El bug que esto evita: con quincena de calendario, el 22 de marzo
        // caería en el periodo 16-31 y el sueldo del 15 quedaría fuera.
        let period = try PayPeriod.current(
            for: date(2026, 3, 22),
            recurringItems: [salary(on: 15)],
            calendar: calendar)

        #expect(try period.contains(date(2026, 3, 15)))
    }

    @Test("El periodo puede cruzar de mes")
    func elPeriodoPuedeCruzarDeMes() throws {
        let period = try PayPeriod.current(
            for: date(2026, 3, 31),
            recurringItems: [salary(on: 30)],
            calendar: calendar)

        #expect(try period.start == date(2026, 3, 30))
        #expect(try period.end == date(2026, 4, 30))
    }

    @Test("Un sueldo el 31 no desaparece en febrero: se recorta al último día real")
    func unSueldoElTreintaYUnoNoDesapareceEnFebrero() throws {
        let period = try PayPeriod.current(
            for: date(2026, 2, 20),
            recurringItems: [salary(on: 31)],
            calendar: calendar)

        #expect(period.isAnchoredToIncome)
        // Febrero de 2026 tiene 28 días.
        #expect(try period.end == date(2026, 2, 28))
    }

    @Test("El periodo se llama como el ingreso que lo ancla")
    func elPeriodoSeLlamaComoElIngresoQueLoAncla() throws {
        let period = try PayPeriod.current(
            for: date(2026, 3, 22),
            recurringItems: [salary(on: 15, name: "Nómina")],
            calendar: calendar)

        #expect(period.anchorName == "Nómina")
    }

    @Test("Sin ingreso recurrente cae a la quincena de calendario, y lo marca")
    func sinIngresoRecurrenteCaeAQuincenaDeCalendario() throws {
        let period = try PayPeriod.current(for: date(2026, 3, 22), recurringItems: [], calendar: calendar)

        #expect(period.isAnchoredToIncome == false)
        #expect(try period.start == date(2026, 3, 16))
        #expect(try period.end == date(2026, 4, 1))
    }

    @Test("La primera quincena de calendario va del 1 al 15")
    func laPrimeraQuincenaDeCalendario() throws {
        let period = try PayPeriod.current(for: date(2026, 3, 8), recurringItems: [], calendar: calendar)

        #expect(try period.start == date(2026, 3, 1))
        #expect(try period.end == date(2026, 3, 16))
    }

    @Test("Un recurrente de gasto no ancla el periodo — solo los ingresos")
    func unRecurrenteDeGastoNoAnclaElPeriodo() throws {
        let rent = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 9000, currency: .mxn),
            kind: .expense,
            category: "hogar",
            dayOfMonth: 5)

        let period = try PayPeriod.current(for: date(2026, 3, 22), recurringItems: [rent], calendar: calendar)

        #expect(period.isAnchoredToIncome == false)
    }
}

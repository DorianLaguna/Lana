import Foundation
import Testing
@testable import LanaCore

@Suite("AvailableProjection")
struct AvailableProjectionTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func movement(
        kind: Expense.Kind,
        amount: Decimal,
        currency: Currency = .mxn,
        date: Date) -> Expense {
        Expense(
            kind: kind,
            amount: Money(amount: amount, currency: currency),
            concept: "algo",
            category: kind == .expense ? "otro" : nil,
            date: date)
    }

    private func salary(on day: Int) throws -> RecurringItem {
        try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 18000, currency: .mxn),
            kind: .income,
            dayOfMonth: day)
    }

    /// Periodo del 15 al 30 de marzo, con hoy en el 22.
    private func period(today: Date) throws -> PayPeriod {
        try PayPeriod.current(
            for: today,
            recurringItems: [salary(on: 15), salary(on: 30)],
            calendar: calendar)
    }

    @Test("Lo que traes es lo que entró menos lo que gastaste en el periodo")
    func loQueTraesEsLoQueEntroMenosLoQueGastaste() throws {
        let today = try date(2026, 3, 22)
        let projection = try AvailableProjection(
            period: period(today: today),
            currency: .mxn,
            expenses: [
                movement(kind: .income, amount: 18000, date: date(2026, 3, 15)),
                movement(kind: .expense, amount: 6200, date: date(2026, 3, 18))
            ],
            upcoming: [],
            asOf: today)

        #expect(projection.received == 18000)
        #expect(projection.spent == 6200)
        #expect(projection.balance == Money(amount: 11800, currency: .mxn))
    }

    @Test("Lo de antes del periodo no cuenta: es dinero de la quincena pasada")
    func loDeAntesDelPeriodoNoCuenta() throws {
        let today = try date(2026, 3, 22)
        let projection = try AvailableProjection(
            period: period(today: today),
            currency: .mxn,
            expenses: [
                movement(kind: .income, amount: 18000, date: date(2026, 3, 1)),
                movement(kind: .income, amount: 18000, date: date(2026, 3, 15))
            ],
            upcoming: [],
            asOf: today)

        #expect(projection.received == 18000)
    }

    @Test("El disponible descuenta los compromisos con fecha que faltan")
    func elDisponibleDescuentaLosCompromisosQueFaltan() throws {
        let today = try date(2026, 3, 22)
        let projection = try AvailableProjection(
            period: period(today: today),
            currency: .mxn,
            expenses: [movement(kind: .income, amount: 18000, date: date(2026, 3, 15))],
            upcoming: [
                Commitment(
                    concept: "Tarjeta",
                    amount: Money(amount: -3400, currency: .mxn),
                    date: date(2026, 3, 24))
            ],
            asOf: today)

        #expect(projection.balance == Money(amount: 18000, currency: .mxn))
        #expect(projection.available == Money(amount: 14600, currency: .mxn))
    }

    @Test("Un compromiso que ya pasó no se descuenta dos veces")
    func unCompromisoQueYaPasoNoSeDescuentaDosVeces() throws {
        let today = try date(2026, 3, 22)
        let projection = try AvailableProjection(
            period: period(today: today),
            currency: .mxn,
            expenses: [movement(kind: .income, amount: 18000, date: date(2026, 3, 15))],
            upcoming: [
                Commitment(
                    concept: "Renta",
                    amount: Money(amount: -9000, currency: .mxn),
                    date: date(2026, 3, 18))
            ],
            asOf: today)

        #expect(projection.upcoming.isEmpty)
        #expect(projection.available == Money(amount: 18000, currency: .mxn))
    }

    @Test("Gastar más de lo que entró deja el disponible en negativo, no en cero")
    func gastarDeMasDejaElDisponibleNegativo() throws {
        let today = try date(2026, 3, 22)
        let projection = try AvailableProjection(
            period: period(today: today),
            currency: .mxn,
            expenses: [
                movement(kind: .income, amount: 5000, date: date(2026, 3, 15)),
                movement(kind: .expense, amount: 8000, date: date(2026, 3, 18))
            ],
            upcoming: [],
            asOf: today)

        #expect(projection.available.amount == -3000)
    }

    @Test("No cruza monedas: los movimientos en otra moneda no entran")
    func noCruzaMonedas() throws {
        let today = try date(2026, 3, 22)
        let projection = try AvailableProjection(
            period: period(today: today),
            currency: .mxn,
            expenses: [
                movement(kind: .income, amount: 18000, currency: .mxn, date: date(2026, 3, 15)),
                movement(kind: .expense, amount: 500, currency: .usd, date: date(2026, 3, 18))
            ],
            upcoming: [],
            asOf: today)

        #expect(projection.spent == 0)
        #expect(projection.balance == Money(amount: 18000, currency: .mxn))
    }

    @Test("La cifra siempre viene con de qué está hecha")
    func laCifraSiempreVieneConDeQueEstaHecha() throws {
        let today = try date(2026, 3, 22)
        let projection = try AvailableProjection(
            period: period(today: today),
            currency: .mxn,
            expenses: [],
            upcoming: [],
            asOf: today)

        #expect(projection.explanation.contains("no de tu banco"))
        #expect(projection.explanation.contains("sueldo"))
    }

    @Test("Sin ingreso recurrente, la explicación dice que va por quincena de calendario")
    func sinIngresoRecurrenteLaExplicacionLoDice() throws {
        let today = try date(2026, 3, 22)
        let projection = AvailableProjection(
            period: PayPeriod.current(for: today, recurringItems: [], calendar: calendar),
            currency: .mxn,
            expenses: [],
            upcoming: [],
            asOf: today)

        #expect(projection.explanation.contains("quincena de calendario"))
    }

    // MARK: - Compromisos sacados de los recurrentes

    @Test("Un recurrente ya registrado este mes no se cuenta otra vez")
    func unRecurrenteYaRegistradoNoSeCuentaOtraVez() throws {
        let today = try date(2026, 3, 22)
        let period = try period(today: today)
        var rent = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 9000, currency: .mxn),
            kind: .expense,
            category: "hogar",
            dayOfMonth: 25)
        rent.lastRegisteredMonth = try date(2026, 3, 1)

        let commitments = period.commitments(from: [rent], registeredIn: [], asOf: today, calendar: calendar)

        #expect(commitments.isEmpty)
    }

    @Test("Un recurrente con su movimiento del mes no cuenta; si se borra el movimiento, vuelve a contar")
    func unRecurrenteConMovimientoNoCuentaYBorrarloLoReabre() throws {
        let today = try date(2026, 3, 22)
        let period = try period(today: today)
        let rent = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 9000, currency: .mxn),
            kind: .expense,
            category: "hogar",
            dayOfMonth: 25)
        // Adelantada el 10, antes de que empiece el periodo del 15.
        let registered = try Expense(
            kind: .expense,
            amount: rent.amount,
            concept: rent.name,
            date: date(2026, 3, 10),
            recurringItemID: rent.id)

        #expect(period.commitments(from: [rent], registeredIn: [registered], asOf: today, calendar: calendar).isEmpty)
        #expect(period.commitments(from: [rent], registeredIn: [], asOf: today, calendar: calendar).count == 1)
    }

    @Test("Un gasto recurrente pendiente resta, y un ingreso recurrente suma")
    func unGastoRestaYUnIngresoSuma() throws {
        let today = try date(2026, 3, 22)
        let period = try period(today: today)
        let rent = try RecurringItem(
            name: "Renta",
            amount: Money(amount: 9000, currency: .mxn),
            kind: .expense,
            category: "hogar",
            dayOfMonth: 25)
        let bonus = try RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 18000, currency: .mxn),
            kind: .income,
            dayOfMonth: 28)

        let commitments = period.commitments(from: [rent, bonus], registeredIn: [], asOf: today, calendar: calendar)
        let byConcept = Dictionary(uniqueKeysWithValues: commitments.map { ($0.concept, $0.amount.amount) })

        #expect(byConcept["Renta"] == -9000)
        #expect(byConcept["Sueldo"] == 18000)
    }

    @Test("Un recurrente fuera del periodo no entra")
    func unRecurrenteFueraDelPeriodoNoEntra() throws {
        let today = try date(2026, 3, 22)
        let period = try period(today: today)
        let subscription = try RecurringItem(
            name: "Netflix",
            amount: Money(amount: 299, currency: .mxn),
            kind: .expense,
            category: "ocio",
            dayOfMonth: 5)

        // El 5 cae antes del 15, o sea fuera de este periodo.
        #expect(period.commitments(from: [subscription], registeredIn: [], asOf: today, calendar: calendar).isEmpty)
    }

    @Test("En un periodo que cruza de mes, sí entra lo que cae del otro lado")
    func enUnPeriodoQueCruzaDeMesEntraLoDelOtroLado() throws {
        let today = try date(2026, 3, 31)
        let period = try PayPeriod.current(
            for: today,
            recurringItems: [salary(on: 30)],
            calendar: calendar)
        let subscription = try RecurringItem(
            name: "Netflix",
            amount: Money(amount: 299, currency: .mxn),
            kind: .expense,
            category: "ocio",
            dayOfMonth: 10)

        let commitments = period.commitments(from: [subscription], registeredIn: [], asOf: today, calendar: calendar)

        // El periodo va del 30 de marzo al 30 de abril: el 10 de abril entra.
        #expect(commitments.count == 1)
        #expect(try commitments.first?.date == date(2026, 4, 10))
    }
}

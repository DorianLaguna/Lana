import Foundation
import Testing
@testable import LanaCore

@Suite("Lo comprometido del mes y lo de cada tarjeta")
struct MonthCommitmentsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func recurring(
        _ name: String,
        _ amount: Decimal,
        day: Int,
        kind: Expense.Kind = .expense) throws -> RecurringItem {
        try RecurringItem(
            name: name,
            amount: Money(amount: amount, currency: .mxn),
            kind: kind,
            dayOfMonth: day)
    }

    private func resolve(
        items: [RecurringItem] = [],
        expenses: [Expense] = [],
        cards: [Card] = [],
        events: [ExpenseEvent] = [],
        asOf: Date) -> MonthCommitments {
        MonthCommitments.resolve(
            month: asOf,
            currency: .mxn,
            from: MonthCommitments.Inputs(
                recurringItems: items,
                expenses: expenses,
                cards: cards,
                ledger: CardLedger(events: events)),
            asOf: asOf,
            calendar: calendar)
    }

    // MARK: - Comprometido: solo recurrentes

    @Test("Un recurrente que todavía no cae en el mes está comprometido")
    func recurrentePendienteCuenta() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 30)], asOf: date(2026, 9, 15))

        #expect(result.recurring.map(\.concept) == ["Renta"])
        #expect(result.committed == 9000)
    }

    @Test("Lo que ya pasó este mes no se vuelve a contar")
    func loYaPasadoNoCuenta() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 1)], asOf: date(2026, 9, 15))

        #expect(result.recurring.isEmpty)
        #expect(result.committed == 0)
    }

    @Test("Un ingreso por venir no suma: cuenta lo registrado, no lo prometido")
    func elIngresoFuturoNoSuma() throws {
        let result = try resolve(
            items: [recurring("Sueldo", 12000, day: 30, kind: .income)],
            asOf: date(2026, 9, 15))

        #expect(result.recurring.isEmpty)
        #expect(result.committed == 0)
    }

    @Test("Lo libre es lo que queda del mes menos los recurrentes")
    func loLibre() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 30)], asOf: date(2026, 9, 15))

        #expect(result.free(after: 12000) == 3000)
    }

    @Test("Lo que cae justo después del mes se ve, pero no se suma")
    func justoDespuesNoSuma() throws {
        let result = try resolve(items: [recurring("Renta", 9000, day: 2)], asOf: date(2026, 9, 28))

        #expect(result.recurring.isEmpty)
        #expect(result.justAfter.map(\.concept) == ["Renta"])
        #expect(result.committed == 0)
    }

    @Test("Un recurrente ya registrado en el mes deja de contar: ya es un gasto real")
    func yaRegistradoNoCuenta() throws {
        let item = try recurring("Renta", 9000, day: 30)
        let registered = Expense(
            kind: .expense,
            amount: Money(amount: 9000, currency: .mxn),
            concept: "Renta",
            category: "hogar",
            date: date(2026, 9, 20),
            recurringItemID: item.id)

        let result = resolve(items: [item], expenses: [registered], asOf: date(2026, 9, 15))

        #expect(result.recurring.isEmpty)
        #expect(result.committed == 0)
    }

    @Test("Sin nada configurado no hay nada que desglosar")
    func vacio() {
        let result = resolve(asOf: date(2026, 9, 15))

        #expect(result.isEmpty)
        #expect(result.committed == 0)
        #expect(result.free(after: 12000) == 12000)
    }

    // MARK: - Tarjetas

    private func creditCard(_ alias: String, cutoffDay: Int, dueDay: Int) throws -> Card {
        try Card(
            alias: alias,
            lastFourDigits: "1234",
            limit: Money(amount: 30000, currency: .mxn),
            cutoffDay: cutoffDay,
            dueDay: dueDay,
            kind: .credit)
    }

    private func charge(_ amount: Decimal, on date: Date, card: Card) -> ExpenseEvent {
        ExpenseEvent.expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "compra",
            category: "otro",
            date: date,
            paymentMethod: .credit(cardID: card.id)))
    }

    private func payment(_ amount: Decimal, on date: Date, card: Card) -> ExpenseEvent {
        ExpenseEvent.cardPaymentRecorded(CardPaymentRecorded(
            cardID: card.id,
            amount: Money(amount: amount, currency: .mxn),
            date: date))
    }

    @Test("Lo facturado y sin pagar se debe este mes, y no entra a lo comprometido")
    func loFacturadoSeDebeEsteMes() throws {
        // Corte el 23: lo gastado antes del corte de agosto ya está facturado.
        let card = try creditCard("Bancomer", cutoffDay: 23, dueDay: 12)
        let result = resolve(
            cards: [card],
            events: [charge(8687, on: date(2026, 8, 20), card: card)],
            asOf: date(2026, 9, 16))

        let bancomer = try #require(result.cards.first)
        #expect(bancomer.card == "Bancomer")
        #expect(bancomer.dueThisMonth == Money(amount: 8687, currency: .mxn))
        // Las tarjetas no son "comprometido": ese renglón es de recurrentes.
        #expect(result.committed == 0)
        #expect(result.cardsDueThisMonth == 8687)
    }

    @Test("Una tarjeta que se sigue debiendo aparece aunque su día límite ya haya pasado")
    func laDeudaNoDesapareceAlVencerse() throws {
        // Día límite el 5, hoy es 16: ya se venció y sigue sin pagarse.
        let card = try creditCard("Bancomer", cutoffDay: 23, dueDay: 5)
        let result = resolve(
            cards: [card],
            events: [charge(8687, on: date(2026, 8, 20), card: card)],
            asOf: date(2026, 9, 16))

        #expect(result.cardsDueThisMonth == 8687)
    }

    @Test("Si ya se pagó el corte, esa tarjeta no se debe este mes")
    func siYaSePagoNoSeDebe() throws {
        // Corte el 7: lo facturado el 7 de septiembre, pagado el 10.
        let card = try creditCard("Banamex", cutoffDay: 7, dueDay: 20)
        let result = resolve(
            cards: [card],
            events: [
                charge(3000, on: date(2026, 9, 3), card: card),
                payment(3000, on: date(2026, 9, 10), card: card)
            ],
            asOf: date(2026, 9, 16))

        #expect(result.cardsDueThisMonth == 0)
    }

    @Test("Lo gastado después del corte es del mes que entra y no se resta de este")
    func despuesDelCorteEsDelSiguiente() throws {
        let card = try creditCard("Banamex", cutoffDay: 7, dueDay: 20)
        let result = resolve(
            cards: [card],
            events: [charge(1450, on: date(2026, 9, 12), card: card)],
            asOf: date(2026, 9, 16))

        let banamex = try #require(result.cards.first)
        #expect(banamex.nextMonth == Money(amount: 1450, currency: .mxn))
        #expect(banamex.dueThisMonth.amount == 0)
        #expect(result.cardsDueThisMonth == 0)
        // Lo libre no lo resiente: esa factura todavía no cierra.
        #expect(result.free(after: 12000) == 12000)
        #expect(result.afterCards(from: 12000) == 12000)
    }

    @Test("Después de tarjetas puede salir negativo, y eso es el dato")
    func despuesDeTarjetasPuedeSerNegativo() throws {
        let card = try creditCard("Bancomer", cutoffDay: 23, dueDay: 12)
        let result = try resolve(
            items: [recurring("Renta", 9000, day: 30)],
            cards: [card],
            events: [charge(8687, on: date(2026, 8, 20), card: card)],
            asOf: date(2026, 9, 16))

        // Quedan 12,000: menos 9,000 de renta son 3,000 libres, y menos los
        // 8,687 de Bancomer, el mes no cierra por 5,687.
        #expect(result.free(after: 12000) == 3000)
        #expect(result.afterCards(from: 12000) == -5687)
    }

    @Test("Una tarjeta sin nada que decir no aparece")
    func sinNadaQueDecirNoAparece() throws {
        let result = try resolve(cards: [creditCard("Nu", cutoffDay: 10, dueDay: 20)], asOf: date(2026, 9, 15))

        #expect(result.cards.isEmpty)
    }

    @Test("Una tarjeta de débito no tiene ciclo de corte: no aparece")
    func elDebitoNoAparece() throws {
        let debit = try Card(
            alias: "Nómina",
            lastFourDigits: "9999",
            limit: nil,
            cutoffDay: nil,
            dueDay: nil,
            kind: .debit)

        let result = resolve(
            cards: [debit],
            events: [charge(500, on: date(2026, 9, 12), card: debit)],
            asOf: date(2026, 9, 16))

        #expect(result.cards.isEmpty)
    }
}

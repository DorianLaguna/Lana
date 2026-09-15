import Foundation
import Testing
@testable import LanaCore

@Suite("PeriodStatistics")
struct PeriodStatisticsTests {
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
        date: Date,
        paymentMethod: PaymentMethod? = nil) -> Expense {
        Expense(
            kind: kind,
            amount: Money(amount: amount, currency: currency),
            concept: "algo",
            category: category,
            subcategory: subcategory,
            date: date,
            paymentMethod: paymentMethod)
    }

    @Test("Separa gastos de ingresos sin mezclar monedas")
    func separaGastosDeIngresosSinMezclarMonedas() throws {
        let day = try date(2026, 3, 10)
        let statistics = PeriodStatistics(expenses: [
            expense(amount: 100, currency: .mxn, date: day),
            expense(amount: 50, currency: .usd, date: day),
            expense(kind: .income, amount: 1000, currency: .mxn, category: nil, date: day)
        ])

        #expect(statistics.currencies == [.mxn, .usd])
        #expect(statistics.total(in: .mxn)?.expenses == 100)
        #expect(statistics.total(in: .mxn)?.income == 1000)
        #expect(statistics.total(in: .usd)?.expenses == 50)
        #expect(statistics.total(in: .usd)?.income == 0)
    }

    @Test("De un gasto compartido cuenta solo la parte de quien mira")
    func deUnGastoCompartidoCuentaSoloLaParteDeQuienMira() throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let listID = SharedListID()
        let shared = try Expense(
            kind: .expense,
            amount: Money(amount: 1000, currency: .mxn),
            concept: "renta",
            category: "hogar",
            date: date(2026, 3, 10),
            sharedListID: listID,
            payer: alice,
            split: .equally(among: [alice, bob]))

        let statistics = PeriodStatistics(expenses: [shared], viewerIdentities: [listID: bob])

        #expect(statistics.total(in: .mxn)?.expenses == 500)
    }

    @Test("Un ingreso cuenta completo — un ingreso no se divide")
    func unIngresoCuentaCompleto() throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let listID = SharedListID()
        let income = try Expense(
            kind: .income,
            amount: Money(amount: 1000, currency: .mxn),
            concept: "sueldo",
            date: date(2026, 3, 10),
            sharedListID: listID,
            payer: alice,
            split: .equally(among: [alice, bob]))

        let statistics = PeriodStatistics(expenses: [income], viewerIdentities: [listID: bob])

        #expect(statistics.total(in: .mxn)?.income == 1000)
    }

    @Test("Un gasto sin categoría cae en otro")
    func unGastoSinCategoriaCaeEnOtro() throws {
        let statistics = try PeriodStatistics(expenses: [
            expense(amount: 100, category: nil, date: date(2026, 3, 10))
        ])

        #expect(statistics.categoryTotals(in: .mxn).first?.category == "otro")
    }

    @Test("Los gastos sin subcategoría no entran al desglose por subcategoría")
    func losGastosSinSubcategoriaNoEntranAlDesglose() throws {
        let day = try date(2026, 3, 10)
        let statistics = PeriodStatistics(expenses: [
            expense(amount: 100, category: "transporte", subcategory: "gasolina", date: day),
            expense(amount: 900, category: "transporte", subcategory: nil, date: day),
            expense(amount: 50, category: "transporte", subcategory: "", date: day)
        ])

        let subcategories = statistics.subcategoryTotals(in: .mxn)
        #expect(subcategories.count == 1)
        #expect(subcategories.first?.category == "gasolina")
    }

    @Test("La forma de pago sin especificar cuenta como efectivo")
    func laFormaDePagoSinEspecificarCuentaComoEfectivo() throws {
        let day = try date(2026, 3, 10)
        let statistics = PeriodStatistics(expenses: [
            expense(amount: 100, date: day, paymentMethod: nil),
            expense(amount: 200, date: day, paymentMethod: .credit(cardID: CardID()))
        ])

        let byMethod = Dictionary(
            uniqueKeysWithValues: statistics.paymentMethodTotals(in: .mxn).map { ($0.category, $0.amount) })
        #expect(byMethod["efectivo"] == 100)
        #expect(byMethod["crédito"] == 200)
    }

    @Test("Sin ingreso registrado la tasa de ahorro no existe, no es cero")
    func sinIngresoLaTasaDeAhorroNoExiste() throws {
        let statistics = try PeriodStatistics(expenses: [
            expense(amount: 100, date: date(2026, 3, 10))
        ])

        #expect(statistics.savingsRate(in: .mxn) == nil)
    }

    @Test("La tasa de ahorro es lo que sobró del ingreso")
    func laTasaDeAhorroEsLoQueSobroDelIngreso() throws {
        let day = try date(2026, 3, 10)
        let statistics = PeriodStatistics(expenses: [
            expense(kind: .income, amount: 1000, category: nil, date: day),
            expense(amount: 750, date: day)
        ])

        #expect(statistics.savingsRate(in: .mxn) == Decimal(string: "0.25"))
    }

    @Test("La tasa de ahorro es negativa cuando se gastó más de lo que entró")
    func laTasaDeAhorroEsNegativaCuandoSeGastoDeMas() throws {
        let day = try date(2026, 3, 10)
        let statistics = PeriodStatistics(expenses: [
            expense(kind: .income, amount: 1000, category: nil, date: day),
            expense(amount: 1500, date: day)
        ])

        let rate = try #require(statistics.savingsRate(in: .mxn))
        #expect(rate < 0)
    }

    @Test("El desglose por categoría de una moneda no incluye las otras")
    func elDesglosePorCategoriaDeUnaMonedaNoIncluyeLasOtras() throws {
        let day = try date(2026, 3, 10)
        let statistics = PeriodStatistics(expenses: [
            expense(amount: 100, currency: .mxn, category: "comida", date: day),
            expense(amount: 999, currency: .usd, category: "comida", date: day)
        ])

        let mxn = statistics.categoryTotals(in: .mxn)
        #expect(mxn.count == 1)
        #expect(mxn.first?.amount == 100)
    }
}

import Foundation
import Testing
@testable import LanaCore

@Suite("BudgetMix")
struct BudgetMixTests {
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

    private func mix(
        _ expenses: [Expense],
        groups: [String: BudgetGroup],
        currency: Currency = .mxn) -> BudgetMix {
        BudgetMix(
            expenses: expenses,
            groupsByLabel: groups,
            currency: currency,
            calendar: calendar)
    }

    // MARK: - La etiqueta que se le manda al modelo

    @Test("La etiqueta que ve el modelo es categoría y subcategoría, sin monto ni fecha ni concepto")
    func laEtiquetaNoLlevaMontoNiFechaNiConcepto() throws {
        let expense = try Expense(
            kind: .expense,
            amount: Money(amount: 1234, currency: .mxn),
            concept: "Starbucks del centro",
            category: "comida",
            subcategory: "café",
            date: date(2026, 3, 10))

        let label = BudgetMix.label(for: expense)

        #expect(label == "comida / café")
        #expect(!label.contains("1234"))
        #expect(!label.contains("Starbucks"))
        #expect(label.rangeOfCharacter(from: .decimalDigits) == nil)
    }

    @Test("Sin subcategoría, la etiqueta es solo la categoría")
    func sinSubcategoriaLaEtiquetaEsLaCategoria() throws {
        let expense = try expense(amount: 100, category: "transporte", date: date(2026, 3, 10))
        #expect(BudgetMix.label(for: expense) == "transporte")
    }

    @Test("La lista que se le manda al modelo no repite etiquetas ni incluye ingresos")
    func laListaNoRepiteEtiquetasNiIncluyeIngresos() throws {
        let day = try date(2026, 3, 10)
        let labels = BudgetMix.labels(in: [
            expense(amount: 50, category: "comida", subcategory: "café", date: day),
            expense(amount: 60, category: "comida", subcategory: "café", date: day),
            expense(amount: 70, category: "hogar", subcategory: "renta", date: day),
            expense(kind: .income, amount: 9999, category: nil, date: day)
        ])

        #expect(labels == ["comida / café", "hogar / renta"])
    }

    // MARK: - Con ingreso registrado

    @Test("Con ingreso, el ahorro es lo que sobró y los grupos suman el ingreso exacto")
    func conIngresoElAhorroEsLoQueSobro() throws {
        let day = try date(2026, 3, 10)
        let mix = mix([
            expense(kind: .income, amount: 10000, category: nil, date: day),
            expense(amount: 5000, category: "hogar", subcategory: "renta", date: day),
            expense(amount: 2000, category: "ocio", subcategory: "cine", date: day)
        ], groups: ["hogar / renta": .necesidad, "ocio / cine": .deseo])

        #expect(mix.isMeasuredAgainstIncome)
        #expect(mix.denominator == 10000)

        let shares = mix.shares(against: .fiftyThirtyTwenty)
        let byGroup = Dictionary(uniqueKeysWithValues: shares.map { ($0.group, $0) })
        #expect(byGroup[.necesidad]?.amount == 5000)
        #expect(byGroup[.deseo]?.amount == 2000)
        // 10 000 − 5 000 − 2 000 = 3 000, que es lo que no se gastó.
        #expect(byGroup[.ahorro]?.amount == 3000)
        #expect(shares.map(\.amount).reduce(0, +) == 10000)
    }

    @Test("Las metas salen de la regla elegida")
    func lasMetasSalenDeLaReglaElegida() throws {
        let day = try date(2026, 3, 10)
        let mix = mix([
            expense(kind: .income, amount: 10000, category: nil, date: day),
            expense(amount: 5000, category: "hogar", date: day)
        ], groups: ["hogar": .necesidad])

        let necesidad = try #require(mix.shares(against: .fiftyThirtyTwenty).first { $0.group == .necesidad })
        #expect(necesidad.share == Decimal(string: "0.5"))
        #expect(necesidad.target == Decimal(string: "0.50"))
        #expect(necesidad.deviation == 0)
    }

    @Test("Cambiar de regla no mueve los porcentajes reales, solo las metas")
    func cambiarDeReglaNoMueveLosPorcentajesReales() throws {
        let day = try date(2026, 3, 10)
        let mix = mix([
            expense(kind: .income, amount: 10000, category: nil, date: day),
            expense(amount: 7000, category: "hogar", date: day)
        ], groups: ["hogar": .necesidad])

        let clasica = try #require(mix.shares(against: .fiftyThirtyTwenty).first { $0.group == .necesidad })
        let ajustada = try #require(mix.shares(against: .seventyTwentyTen).first { $0.group == .necesidad })

        #expect(clasica.share == ajustada.share)
        #expect(clasica.target == Decimal(string: "0.50"))
        #expect(ajustada.target == Decimal(string: "0.70"))
    }

    @Test("Sin regla elegida hay mezcla pero no hay metas")
    func sinReglaElegidaNoHayMetas() throws {
        let day = try date(2026, 3, 10)
        let mix = mix([
            expense(kind: .income, amount: 10000, category: nil, date: day),
            expense(amount: 5000, category: "hogar", date: day)
        ], groups: ["hogar": .necesidad])

        #expect(mix.shares(against: nil).allSatisfy { $0.target == nil })
    }

    @Test("Págate primero solo fija meta de ahorro; lo demás es dato sin comparación")
    func paguatePrimeroSoloFijaMetaDeAhorro() throws {
        let day = try date(2026, 3, 10)
        let mix = mix([
            expense(kind: .income, amount: 10000, category: nil, date: day),
            expense(amount: 5000, category: "hogar", date: day)
        ], groups: ["hogar": .necesidad])

        let byGroup = Dictionary(
            uniqueKeysWithValues: mix.shares(against: .payYourselfFirst).map { ($0.group, $0) })
        #expect(byGroup[.ahorro]?.target == Decimal(string: "0.20"))
        #expect(byGroup[.necesidad]?.target == nil)
        #expect(byGroup[.deseo]?.target == nil)
    }

    @Test("Gastar más de lo que entró deja el ahorro en negativo, no en cero")
    func gastarDeMasDejaElAhorroNegativo() throws {
        let day = try date(2026, 3, 10)
        let mix = mix([
            expense(kind: .income, amount: 1000, category: nil, date: day),
            expense(amount: 1500, category: "hogar", date: day)
        ], groups: ["hogar": .necesidad])

        let ahorro = try #require(mix.shares(against: nil).first { $0.group == .ahorro })
        #expect(ahorro.amount == -500)
    }

    // MARK: - Sin clasificar

    @Test("Lo que el modelo no etiquetó se reporta aparte, nunca se reparte")
    func loNoEtiquetadoSeReportaAparte() throws {
        let day = try date(2026, 3, 10)
        let mix = mix([
            expense(kind: .income, amount: 10000, category: nil, date: day),
            expense(amount: 4000, category: "hogar", date: day),
            expense(amount: 1000, category: "misterio", date: day)
        ], groups: ["hogar": .necesidad])

        #expect(mix.unclassified == 1000)
        let byGroup = Dictionary(uniqueKeysWithValues: mix.shares(against: nil).map { ($0.group, $0) })
        #expect(byGroup[.necesidad]?.amount == 4000)
        #expect(byGroup[.deseo]?.amount == 0)
        // El ahorro descuenta lo no clasificado: si no, diría que sobraron
        // 6 000 cuando 1 000 ya se habían gastado en algo sin etiquetar.
        #expect(byGroup[.ahorro]?.amount == 5000)
    }

    // MARK: - Sin ingreso registrado

    @Test("Sin ingreso, los porcentajes se miden contra el gasto y no hay metas")
    func sinIngresoSeMideContraElGastoYNoHayMetas() throws {
        let day = try date(2026, 3, 10)
        let mix = mix([
            expense(amount: 750, category: "hogar", date: day),
            expense(amount: 250, category: "ocio", date: day)
        ], groups: ["hogar": .necesidad, "ocio": .deseo])

        #expect(mix.isMeasuredAgainstIncome == false)
        #expect(mix.denominator == 1000)

        let shares = mix.shares(against: .fiftyThirtyTwenty)
        #expect(shares.map(\.group) == [.necesidad, .deseo])
        #expect(shares.allSatisfy { $0.target == nil })
        #expect(shares.first?.share == Decimal(string: "0.75"))
    }

    @Test("Sin ingreso no aparece el tramo de ahorro — no se sabe qué sobró")
    func sinIngresoNoApareceElTramoDeAhorro() throws {
        let mix = try mix([
            expense(amount: 100, category: "hogar", date: date(2026, 3, 10))
        ], groups: ["hogar": .necesidad])

        #expect(!mix.shares(against: nil).contains { $0.group == .ahorro })
    }

    // MARK: - Multi-moneda y compartidos

    @Test("Nunca cruza monedas: la mezcla es de una sola")
    func nuncaCruzaMonedas() throws {
        let day = try date(2026, 3, 10)
        let expenses = [
            expense(kind: .income, amount: 10000, currency: .mxn, category: nil, date: day),
            expense(amount: 5000, currency: .mxn, category: "hogar", date: day),
            expense(amount: 999, currency: .usd, category: "hogar", date: day)
        ]

        let mxn = mix(expenses, groups: ["hogar": .necesidad], currency: .mxn)
        let necesidad = try #require(mxn.shares(against: nil).first { $0.group == .necesidad })
        #expect(necesidad.amount == 5000)
    }

    @Test("De un gasto compartido cuenta solo la parte de quien mira")
    func deUnCompartidoCuentaSoloLaParteDeQuienMira() throws {
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

        let mix = BudgetMix(
            expenses: [shared],
            groupsByLabel: ["hogar": .necesidad],
            viewerIdentities: [listID: bob],
            currency: .mxn,
            calendar: calendar)

        let necesidad = try #require(mix.shares(against: nil).first { $0.group == .necesidad })
        #expect(necesidad.amount == 500)
    }

    // MARK: - La guarda de la sugerencia

    @Test("Sin ingreso no hay material para sugerir una regla")
    func sinIngresoNoHayMaterialParaSugerir() throws {
        let expenses = try (1 ... 20).map { day in
            try expense(amount: 100, category: "hogar", date: date(2026, 3, day))
        }
        #expect(mix(expenses, groups: ["hogar": .necesidad]).isEnoughForRecommendation == false)
    }

    @Test("Con un solo mes de datos tampoco se sugiere: sería ruido presentado como consejo")
    func conUnSoloMesNoSeSugiere() throws {
        var expenses = try (1 ... 20).map { day in
            try expense(amount: 100, category: "hogar", date: date(2026, 3, day))
        }
        try expenses.append(expense(kind: .income, amount: 9000, category: nil, date: date(2026, 3, 1)))

        #expect(mix(expenses, groups: ["hogar": .necesidad]).isEnoughForRecommendation == false)
    }

    @Test("Con ingreso, dos meses y suficientes movimientos, ya se puede sugerir")
    func conSuficienteMaterialSeSugiere() throws {
        var expenses = try (1 ... 10).map { day in
            try expense(amount: 100, category: "hogar", date: date(2026, 3, day))
        }
        expenses += try (1 ... 10).map { day in
            try expense(amount: 100, category: "hogar", date: date(2026, 4, day))
        }
        try expenses.append(expense(kind: .income, amount: 9000, category: nil, date: date(2026, 3, 1)))

        #expect(mix(expenses, groups: ["hogar": .necesidad]).isEnoughForRecommendation)
    }
}

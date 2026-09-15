import Foundation
import Testing
@testable import LanaCore

/// Lo que estas pruebas cuidan es que las herramientas devuelvan cifras
/// correctas **sin modelo de por medio**: el modelo elige cuál llamar y narra
/// lo que regrese, así que si aquí sale un número mal, sale mal en la
/// respuesta (Docs/CLAUDE.md).
@Suite("LedgerToolbox")
struct LedgerToolboxTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func expense(
        amount: Decimal,
        currency: Currency = .mxn,
        concept: String = "algo",
        category: String = "hogar",
        date: Date) -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: currency),
            concept: concept,
            category: category,
            date: date)
    }

    private func toolbox(
        store: InMemoryExpenseStore = InMemoryExpenseStore(),
        sharedListStore: InMemorySharedListStore = InMemorySharedListStore(),
        cardStore: InMemoryCardStore = InMemoryCardStore(),
        recurringItemStore: InMemoryRecurringItemStore? = nil) -> LedgerToolbox {
        LedgerToolbox(
            store: store,
            sharedListStore: sharedListStore,
            cardStore: cardStore,
            cardPaymentStore: InMemoryCardPaymentStore(),
            recurringItemStore: recurringItemStore,
            calendar: calendar)
    }

    @Test("El total por categoría trae el desglose del mes pedido")
    func elTotalPorCategoriaTraeElDesglose() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 300, category: "comida", date: date(2026, 3, 5)))
        try await store.save(expense(amount: 700, category: "hogar", date: date(2026, 3, 6)))
        try await store.save(expense(amount: 999, category: "ocio", date: date(2026, 4, 6)))

        let answer = await toolbox(store: store).totalPorCategoria(year: 2026, month: 3)

        #expect(answer.contains("1,000"))
        #expect(answer.contains("comida"))
        #expect(answer.contains("hogar"))
        // Abril no entra.
        #expect(!answer.contains("ocio"))
    }

    @Test("Un mes que no existe se rechaza en vez de inventar un rango")
    func unMesQueNoExisteSeRechaza() async {
        let answer = await toolbox().totalPorCategoria(year: 2026, month: 13)
        #expect(answer == "Ese mes no existe.")
    }

    @Test("Un mes sin movimientos lo dice, no devuelve ceros")
    func unMesSinMovimientosLoDice() async {
        let answer = await toolbox().totalPorCategoria(year: 2026, month: 3)
        #expect(answer.contains("No hay movimientos"))
    }

    @Test("No mezcla monedas: cada una en su propio bloque")
    func noMezclaMonedas() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 1000, currency: .mxn, date: date(2026, 3, 5)))
        try await store.save(expense(amount: 50, currency: .usd, date: date(2026, 3, 6)))

        let answer = await toolbox(store: store).totalPorCategoria(year: 2026, month: 3)

        #expect(answer.contains("MXN"))
        #expect(answer.contains("USD"))
        // 1000 + 50 nunca aparece como un solo número.
        #expect(!answer.contains("1,050"))
    }

    @Test("Comparar meses dice cuánto cambió y en qué categorías")
    func compararMesesDiceCuantoCambio() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 1000, category: "comida", date: date(2026, 2, 5)))
        try await store.save(expense(amount: 1500, category: "comida", date: date(2026, 3, 5)))

        let answer = await toolbox(store: store)
            .comparaMeses(yearA: 2026, monthA: 3, yearB: 2026, monthB: 2)

        #expect(answer.contains("subió"))
        #expect(answer.contains("500"))
        #expect(answer.contains("comida"))
    }

    @Test("Los mayores gastos vienen con su concepto, de mayor a menor")
    func losMayoresGastosVienenConSuConcepto() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, concept: "café", date: date(2026, 3, 5)))
        try await store.save(expense(amount: 5000, concept: "renta", date: date(2026, 3, 1)))

        let answer = await toolbox(store: store).mayoresGastos(year: 2026, month: 3, limit: 5)

        let rentaIndex = try #require(answer.range(of: "renta"))
        let cafeIndex = try #require(answer.range(of: "café"))
        #expect(rentaIndex.lowerBound < cafeIndex.lowerBound)
    }

    @Test("El límite de los mayores gastos se acota, aunque el modelo pida un número absurdo")
    func elLimiteSeAcota() async throws {
        let store = InMemoryExpenseStore()
        for day in 1 ... 20 {
            try await store.save(expense(amount: Decimal(day), concept: "gasto \(day)", date: date(2026, 3, day)))
        }

        let answer = await toolbox(store: store).mayoresGastos(year: 2026, month: 3, limit: 999)

        // Diez es el tope; se cuentan los renglones con sangría.
        #expect(answer.components(separatedBy: "\n  ").count - 1 == 10)
    }

    @Test("De un gasto compartido, las herramientas cuentan solo la parte de quien pregunta")
    func lasHerramientasCuentanSoloLaParteDeQuienPregunta() async throws {
        let alice = ParticipantID()
        let bob = ParticipantID()
        let list = SharedList(
            name: "Casa",
            participants: [
                Participant(id: alice, displayName: "Alice"),
                Participant(id: bob, displayName: "Bob")
            ],
            defaultSplit: .equally(among: [alice, bob]))
        let sharedListStore = InMemorySharedListStore()
        try await sharedListStore.save(list)
        try await sharedListStore.setViewerParticipantID(bob, for: list.id)

        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 1000, currency: .mxn),
            concept: "renta",
            category: "hogar",
            date: date(2026, 3, 1),
            sharedListID: list.id,
            payer: alice,
            split: .equally(among: [alice, bob])))

        let answer = await toolbox(store: store, sharedListStore: sharedListStore)
            .totalPorCategoria(year: 2026, month: 3)

        #expect(answer.contains("500"))
        #expect(!answer.contains("1,000"))
    }

    @Test("Preguntar por una lista que no existe dice cuáles sí existen")
    func preguntarPorUnaListaQueNoExisteDiceCualesSi() async throws {
        let sharedListStore = InMemorySharedListStore()
        try await sharedListStore.save(SharedList(
            name: "Casa",
            participants: [Participant(id: ParticipantID(), displayName: "Alice")],
            defaultSplit: .payerOnly))

        let answer = await toolbox(sharedListStore: sharedListStore).saldoDeLista(name: "Viaje")

        #expect(answer.contains("no hay una lista") || answer.contains("No hay una lista"))
        #expect(answer.contains("Casa"))
    }

    @Test("El nombre de la lista se empareja sin acentos ni mayúsculas")
    func elNombreSeEmparejaSinAcentos() async throws {
        let sharedListStore = InMemorySharedListStore()
        try await sharedListStore.save(SharedList(
            name: "Vacaciones",
            participants: [Participant(id: ParticipantID(), displayName: "Alice")],
            defaultSplit: .payerOnly))

        let answer = await toolbox(sharedListStore: sharedListStore).saldoDeLista(name: "  vacaciónes ")

        #expect(!answer.contains("No hay una lista"))
    }

    @Test("Sin tarjetas de crédito lo dice, en vez de devolver una deuda de cero")
    func sinTarjetasDeCreditoLoDice() async {
        let answer = await toolbox().deudaPorTarjeta()
        #expect(answer.contains("No hay tarjetas de crédito"))
    }

    // MARK: - Disponible proyectado

    @Test("El disponible sale del sueldo registrado menos lo gastado desde entonces")
    func elDisponibleSaleDelSueldoMenosLoGastado() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .income,
            amount: Money(amount: 18000, currency: .mxn),
            concept: "sueldo",
            date: date(2026, 3, 15)))
        try await store.save(expense(amount: 6200, date: date(2026, 3, 18)))

        let recurring = InMemoryRecurringItemStore()
        try await recurring.save(RecurringItem(
            name: "Sueldo",
            amount: Money(amount: 18000, currency: .mxn),
            kind: .income,
            dayOfMonth: 15))

        let answer = try await toolbox(store: store, recurringItemStore: recurring)
            .disponibleProyectado(asOf: date(2026, 3, 22))

        #expect(answer.contains("11,800"))
        #expect(answer.contains("no de tu banco"))
    }

    @Test("La respuesta del disponible siempre dice de qué está hecha")
    func elDisponibleSiempreDiceDeQueEstaHecho() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 100, date: date(2026, 3, 18)))

        let answer = try await toolbox(store: store, recurringItemStore: InMemoryRecurringItemStore())
            .disponibleProyectado(asOf: date(2026, 3, 22))

        #expect(answer.contains("no de tu banco"))
    }

    @Test("Sin recurrentes de dónde sacar el periodo, el disponible no se inventa")
    func sinRecurrentesElDisponibleNoSeInventa() async {
        let answer = await toolbox().disponibleProyectado()
        #expect(answer == "Todavía no puedo calcular eso.")
    }

    // MARK: - De dónde vino el dinero (ADR-0040)

    @Test("El origen del ingreso desglosa por su propio catálogo")
    func elOrigenDelIngresoDesglosa() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .income,
            amount: Money(amount: 18000, currency: .mxn),
            concept: "quincena",
            category: IncomeCategory.sueldo.rawValue,
            date: date(2026, 3, 15)))
        try await store.save(Expense(
            kind: .income,
            amount: Money(amount: 4000, currency: .mxn),
            concept: "diseño",
            category: IncomeCategory.freelance.rawValue,
            date: date(2026, 3, 20)))

        let answer = await toolbox(store: store).origenDelIngreso(year: 2026, month: 3)

        #expect(answer.contains("sueldo"))
        #expect(answer.contains("freelance"))
        #expect(answer.contains("22,000"))
    }

    @Test("Los gastos no se cuelan al desglose de ingresos")
    func losGastosNoSeCuelanAlDesgloseDeIngresos() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .income,
            amount: Money(amount: 18000, currency: .mxn),
            concept: "quincena",
            category: IncomeCategory.sueldo.rawValue,
            date: date(2026, 3, 15)))
        try await store.save(expense(amount: 500, category: "comida", date: date(2026, 3, 16)))

        let answer = await toolbox(store: store).origenDelIngreso(year: 2026, month: 3)

        #expect(!answer.contains("comida"))
    }

    @Test("Un ingreso sin categoría cae en otro, no desaparece")
    func unIngresoSinCategoriaCaeEnOtro() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .income,
            amount: Money(amount: 900, currency: .mxn),
            concept: "algo",
            date: date(2026, 3, 15)))

        let answer = await toolbox(store: store).origenDelIngreso(year: 2026, month: 3)

        #expect(answer.contains("otro"))
        #expect(answer.contains("900"))
    }

    @Test("Un mes sin ingresos lo dice, en vez de listar cero")
    func unMesSinIngresosLoDice() async throws {
        let store = InMemoryExpenseStore()
        try await store.save(expense(amount: 500, date: date(2026, 3, 16)))

        let answer = await toolbox(store: store).origenDelIngreso(year: 2026, month: 3)

        #expect(answer.contains("No hay ingresos"))
    }

    @Test("El catálogo nombra las herramientas que de verdad existen")
    func elCatalogoNombraLasHerramientasQueExisten() {
        let names = Set(LedgerToolbox.catalog.map(\.name))
        #expect(names == [
            "totalPorCategoria",
            "comparaMeses",
            "mayoresGastos",
            "saldoDeLista",
            "deudaPorTarjeta",
            "disponibleProyectado",
            "origenDelIngreso"
        ])
        #expect(LedgerToolbox.catalog.allSatisfy { !$0.toolDescription.isEmpty })
    }
}

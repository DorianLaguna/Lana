import Foundation
import LanaCore
import Testing
@testable import InsightsFeature

/// El bug reportado: estando en agosto, preguntar "¿cuáles fueron mis gastos
/// más grandes?" contestaba sobre septiembre. La pregunta no nombra el mes
/// porque la persona ya lo está viendo, y lo único que el modelo tenía era la
/// fecha de hoy.
@Suite("InsightsModel — la pregunta sabe qué periodo estás viendo")
@MainActor
struct InsightsQueryPeriodTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func makeModel(spy: SpyQuerying, referenceDate: Date) throws -> InsightsModel {
        try InsightsModel(
            store: InMemoryExpenseStore(),
            sharedListStore: InMemorySharedListStore(),
            classifier: InMemorySpendingClassifying(),
            narrator: InMemoryInsightNarrating(),
            querying: spy,
            preference: BudgetRulePreference(
                userDefaults: #require(UserDefaults(suiteName: "lana.tests.\(UUID().uuidString)"))),
            referenceDate: referenceDate,
            calendar: calendar)
    }

    @Test("Viendo el mes de hoy, pregunta sobre el mes de hoy")
    func viendoElMesDeHoyPreguntaSobreElMesDeHoy() async throws {
        let spy = SpyQuerying()
        let model = try makeModel(spy: spy, referenceDate: date(2026, 9, 15))

        model.question = "¿Cuáles fueron mis gastos más grandes?"
        await model.ask()

        let period = try #require(await spy.lastPeriod)
        #expect(period.year == 2026)
        #expect(period.month == 9)
    }

    @Test("Viendo agosto, la pregunta va sobre agosto y no sobre septiembre")
    func viendoAgostoLaPreguntaVaSobreAgosto() async throws {
        let spy = SpyQuerying()
        let model = try makeModel(spy: spy, referenceDate: date(2026, 9, 15))
        await model.goToPrevious()

        model.question = "¿Cuáles fueron mis gastos más grandes?"
        await model.ask()

        let period = try #require(await spy.lastPeriod)
        #expect(period.month == 8)
        #expect(period.year == 2026)
    }

    @Test("Viendo el año completo, el periodo va sin mes")
    func viendoElAnioElPeriodoVaSinMes() async throws {
        let spy = SpyQuerying()
        let model = try makeModel(spy: spy, referenceDate: date(2026, 9, 15))
        await model.select(.year)

        model.question = "¿En qué se me fue el dinero?"
        await model.ask()

        let period = try #require(await spy.lastPeriod)
        #expect(period.month == nil)
        #expect(period.year == 2026)
    }

    @Test("Viendo un año anterior, la pregunta va sobre ese año")
    func viendoUnAnioAnteriorLaPreguntaVaSobreEseAnio() async throws {
        let spy = SpyQuerying()
        let model = try makeModel(spy: spy, referenceDate: date(2026, 9, 15))
        await model.select(.year)
        await model.goToPrevious()

        model.question = "¿En qué se me fue el dinero?"
        await model.ask()

        #expect(await spy.lastPeriod?.year == 2025)
    }

    @Test("Borrar deja la pregunta y la respuesta en blanco")
    func borrarDejaTodoEnBlanco() async throws {
        let spy = SpyQuerying()
        let model = try makeModel(spy: spy, referenceDate: date(2026, 9, 15))
        model.question = "¿Cuánto gasté?"
        await model.ask()
        #expect(model.answer != nil)

        model.clearQuestion()

        #expect(model.question.isEmpty)
        #expect(model.answer == nil)
    }

    @Test("Borrar la pregunta no tira el análisis del periodo")
    func borrarNoTiraElAnalisis() async throws {
        // El botón de borrar es de la conversación, no del análisis: si tirara
        // la caché, borrar una pregunta obligaría a releer el store y a volver
        // a llamar al modelo.
        let spy = SpyQuerying()
        let model = try makeModel(spy: spy, referenceDate: date(2026, 9, 15))
        await model.onAppear()
        let periodBefore = model.period
        let anchorBefore = model.anchor

        model.question = "¿Cuánto gasté?"
        await model.ask()
        model.clearQuestion()

        #expect(model.period == periodBefore)
        #expect(model.anchor == anchorBefore)
    }

    @Test("Tocar un chip deja su pregunta en el campo y contesta sin consultar al modelo")
    func preguntarUnaSugeridaDejaLaPreguntaEnElCampo() async throws {
        let spy = SpyQuerying()
        let model = try makeModel(spy: spy, referenceDate: date(2026, 9, 15))

        await model.ask(.deudaDeTarjetas)

        #expect(model.question == QuickAnswer.deudaDeTarjetas.title)
        // La cifra sale del cálculo determinista, no de una narración.
        #expect(model.answer == "No hay tarjetas de crédito registradas.")
        // Y el modelo nunca se enteró: es lo que distingue un chip de una
        // pregunta escrita a mano.
        #expect(await spy.lastPeriod == nil)
    }

    @Test("Viendo el año no se ofrecen las preguntas que necesitan un mes")
    func viendoElAnioSoloSeOfrecenLasQueAplican() async throws {
        let model = try makeModel(spy: SpyQuerying(), referenceDate: date(2026, 9, 15))
        #expect(model.quickAnswers.count == 6)

        await model.select(.year)

        #expect(model.quickAnswers == [.deudaDeTarjetas, .cuantoQueda])
    }

    @Test("Una pregunta en blanco no llega al modelo")
    func unaPreguntaEnBlancoNoLlegaAlModelo() async throws {
        let spy = SpyQuerying()
        let model = try makeModel(spy: spy, referenceDate: date(2026, 9, 15))

        model.question = "   "
        await model.ask()

        #expect(await spy.lastPeriod == nil)
    }
}

/// Anota con qué periodo se le preguntó.
private actor SpyQuerying: InsightQuerying {
    private(set) var lastPeriod: QueryPeriod?

    nonisolated var availability: ParsingAvailability {
        get async { .available }
    }

    func answer(_: String, viewing period: QueryPeriod) async throws -> String {
        lastPeriod = period
        return "respuesta"
    }
}

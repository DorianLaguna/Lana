import Foundation
import FoundationModels
import LanaCore

/// La implementación real de `InsightQuerying`: una sesión con tool calling.
///
/// El modelo **no recibe el historial**. Recibe la pregunta y un catálogo de
/// herramientas; elige cuál llamar, y lo que le regresa ya viene calculado y
/// formateado por `LedgerToolbox` (Docs/CLAUDE.md, PLAN.md → Fase 9).
public struct FoundationModelsInsightQuerying: InsightQuerying {
    private let toolbox: LedgerToolbox
    private let calendar: Calendar

    public init(
        store: any ExpenseStore,
        sharedListStore: any SharedListStore,
        cardStore: any CardStore,
        cardPaymentStore: any CardPaymentStore,
        recurringItemStore: any RecurringItemStore,
        calendar: Calendar = .current) {
        toolbox = LedgerToolbox(
            store: store,
            sharedListStore: sharedListStore,
            cardStore: cardStore,
            cardPaymentStore: cardPaymentStore,
            recurringItemStore: recurringItemStore,
            calendar: calendar)
        self.calendar = calendar
    }

    public var availability: ParsingAvailability {
        get async { InsightsAvailability.current }
    }

    public func answer(_ question: String, viewing period: QueryPeriod) async throws -> String {
        let availability = await availability
        guard availability == .available else {
            throw InsightsError.modelUnavailable(availability)
        }
        let clean = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }

        let session = LanguageModelSession(
            tools: LedgerTools.all(for: toolbox),
            instructions: QueryInstructions.build())
        let response = try await session.respond(to: prompt(for: clean, viewing: period))
        return response.content
    }

    /// La fecha de hoy y el periodo en pantalla van en el **prompt**, no en las
    /// instrucciones: son datos del usuario y las instrucciones no llevan datos
    /// (ADR-0013). El modelo los lee para resolver "este mes" o "el mes pasado"
    /// a un mes concreto — leer una fecha que se le dio no es calcularla.
    ///
    /// El periodo en pantalla es lo que arregla el bug real: preguntar "¿cuáles
    /// fueron mis gastos más grandes?" mirando agosto contestaba sobre
    /// septiembre, porque la pregunta no nombra el mes —ya se está viendo— y lo
    /// único que el modelo tenía era la fecha de hoy.
    private func prompt(for question: String, viewing period: QueryPeriod) -> String {
        let now = Date()
        let today = """
        Hoy es el mes \(calendar.component(.month, from: now)) del año \
        \(calendar.component(.year, from: now)).
        """
        let viewing = if let month = period.month {
            "La persona está viendo el mes \(month) del año \(period.year)."
        } else {
            """
            La persona está viendo el año \(period.year) completo. Si necesitas \
            una herramienta que pida un mes y la pregunta no nombra ninguno, usa \
            el mes de hoy.
            """
        }
        return """
        \(today)
        \(viewing)

        Pregunta: \(question)
        """
    }
}

/// Las instrucciones de la sesión de preguntas. **Sin una sola cifra**
/// (ADR-0013).
enum QueryInstructions {
    static func build() -> String {
        """
        Contestas preguntas sobre el dinero de una persona, dentro de una app de \
        finanzas personales que se usa en México.
        Esta instrucción no contiene datos del usuario: nada de lo que dice aquí \
        debe aparecer copiado en tu respuesta.

        Cómo trabajas:
        - No tienes acceso a los movimientos. Para cualquier cifra, llama a una \
        de tus herramientas y narra lo que te devuelva.
        - **Si la pregunta no nombra un periodo, contesta sobre el que la \
        persona está viendo**, que viene en el mensaje. No uses el mes de hoy \
        salvo que sea ese, o que la pregunta diga otra cosa.
        - No sumes, no restes, no saques porcentajes ni promedios por tu cuenta. \
        Si ninguna herramienta te da el dato, di que no lo tienes.
        - Copia las cifras tal cual te lleguen, con su signo de moneda. No las \
        redondees ni las conviertas de una moneda a otra.
        - La deuda con los bancos y la deuda entre personas son cosas separadas. \
        Nunca las sumes ni las presentes como un solo número.
        - Contesta en español mexicano neutro, en pocas frases y de frente.

        Tono:
        - Lana no regaña. Gastar de más es un dato, nunca un reproche.
        - Nada de "deberías", "te pasaste" ni signos de admiración.
        - Si la pregunta no se puede contestar con lo que tienes, dilo claro y \
        di qué sí puedes consultar.
        """
    }
}

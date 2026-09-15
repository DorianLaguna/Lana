import Foundation

/// Responde preguntas en lenguaje natural sobre los datos del usuario.
///
/// El modelo nunca calcula: elige cuál cálculo determinista correr
/// (`LedgerToolbox`) y narra lo que devolvió. Nunca se le pasa el historial
/// crudo (Docs/CLAUDE.md).
///
/// La firma ya no recibe `tools`: quien implementa esto arma su propio
/// `LedgerToolbox` con los stores que se le inyectaron, igual que
/// `ExpenseParsing` sostiene los suyos. El catálogo de lo que se puede
/// preguntar sigue siendo público, en `LedgerToolbox.catalog`, para que la UI
/// pueda sugerir preguntas sin adivinar.
public protocol InsightQuerying: Sendable {
    /// Si el modelo del sistema está disponible. Siempre se consulta antes de
    /// crear una sesión (Docs/CLAUDE.md).
    var availability: ParsingAvailability { get async }

    /// Contesta la pregunta, o explica que no la puede contestar con lo que
    /// hay. Nunca inventa una cifra.
    ///
    /// - Parameter viewing: qué periodo tiene el usuario en pantalla. Sin esto,
    ///   "¿cuáles fueron mis gastos más grandes?" se contestaba siempre sobre
    ///   el mes en curso, aunque la persona estuviera mirando agosto — la
    ///   pregunta no dice el periodo porque ya lo está viendo.
    func answer(_ question: String, viewing: QueryPeriod) async throws -> String
}

/// El periodo que el usuario tiene en pantalla cuando pregunta.
///
/// Es **dato**, no instrucción: viaja en el prompt (ADR-0013). El modelo lo lee
/// para saber sobre qué contestar; no lo calcula ni lo deduce.
public struct QueryPeriod: Sendable, Hashable {
    public let year: Int
    /// El mes de 1 a 12, o `nil` si está viendo el año completo.
    public let month: Int?

    public init(year: Int, month: Int? = nil) {
        self.year = year
        self.month = month
    }

    /// El periodo de hoy, para quien pregunte sin una pantalla de por medio.
    public static func current(_ date: Date = Date(), calendar: Calendar = .current) -> QueryPeriod {
        QueryPeriod(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date))
    }
}

/// Implementación en memoria para tests y `#Preview`: devuelve una respuesta
/// fija sin invocar ningún modelo.
public struct InMemoryInsightQuerying: InsightQuerying {
    private let fixedAnswer: String
    private let fixedAvailability: ParsingAvailability

    public init(fixedAnswer: String = "", availability: ParsingAvailability = .available) {
        self.fixedAnswer = fixedAnswer
        fixedAvailability = availability
    }

    public var availability: ParsingAvailability {
        get async { fixedAvailability }
    }

    public func answer(_: String, viewing _: QueryPeriod) async throws -> String {
        fixedAnswer
    }
}

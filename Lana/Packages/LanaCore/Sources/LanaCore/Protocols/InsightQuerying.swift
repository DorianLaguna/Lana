/// Responde preguntas en lenguaje natural sobre los datos del usuario. El
/// modelo nunca calcula — solo narra el resultado de `tools` deterministas
/// (Docs/CLAUDE.md). El catálogo real de tools se define en la Fase 9.
public protocol InsightQuerying: Sendable {
    func answer(_ question: String, tools: [LedgerTool]) async throws -> String
}

/// Implementación en memoria para tests y `#Preview`: devuelve una respuesta
/// fija sin invocar ningún modelo.
public struct InMemoryInsightQuerying: InsightQuerying {
    private let fixedAnswer: String

    public init(fixedAnswer: String = "") {
        self.fixedAnswer = fixedAnswer
    }

    public func answer(_ question: String, tools: [LedgerTool]) async throws -> String {
        fixedAnswer
    }
}

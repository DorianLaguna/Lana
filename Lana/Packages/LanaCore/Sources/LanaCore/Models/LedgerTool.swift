/// Una herramienta determinista que `InsightQuerying` le ofrece al modelo
/// para responder consultas en lenguaje natural — el modelo narra el
/// resultado, nunca calcula (Docs/CLAUDE.md). Forma mínima para que el
/// protocolo compile en Fase 1; el catálogo real de tools
/// (`totalPorCategoria`, `saldoDeLista`, ...) se define en la Fase 9.
public struct LedgerTool: Sendable, Hashable {
    public var name: String
    public var toolDescription: String

    public init(name: String, toolDescription: String) {
        self.name = name
        self.toolDescription = toolDescription
    }
}

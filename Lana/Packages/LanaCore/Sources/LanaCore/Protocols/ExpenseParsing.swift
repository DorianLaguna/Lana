/// Los cuatro casos de disponibilidad del parser — cada uno necesita
/// tratamiento distinto en la UI (Docs/.claude/skills/foundation-models):
///
/// - `.available`: único caso donde el flujo de captura funciona.
/// - `.deviceNotEligible`: permanente. Pantalla explicativa, sin reintentar.
/// - `.notEnabled`: recuperable. Botón que lleva a Settings.
/// - `.modelNotReady`: temporal, se está descargando. Espera + reintento.
///
/// Vive en `LanaCore` (no en `LanaParsing`) porque las features solo pueden
/// depender de `LanaCore`/`LanaDesign`, nunca de una implementación
/// concreta — sin esto aquí, `EntryFeature` no podría mostrar el
/// onboarding de disponibilidad.
public enum ParsingAvailability: Sendable, Equatable {
    case available
    case deviceNotEligible
    case notEnabled
    case modelNotReady
    case unknown
}

/// Convierte texto libre en transacciones candidatas. La implementación real
/// (`LanaParsing`, Fase 3) usa `FoundationModels` + `AmountValidator`; el
/// resto del sistema solo conoce este protocolo.
public protocol ExpenseParsing: Sendable {
    var availability: ParsingAvailability { get async }
    /// Carga el modelo en memoria por anticipado — se llama al abrir la
    /// pantalla de captura, no al confirmar, para que la primera respuesta
    /// se sienta inmediata (Docs/.claude/skills/foundation-models).
    func prewarm()
    func parse(_ text: String) async throws -> [ParseResult]
}

/// Implementación en memoria para tests y `#Preview`: devuelve resultados
/// fijos sin invocar ningún modelo.
public struct InMemoryExpenseParsing: ExpenseParsing {
    private let results: [ParseResult]
    public let availability: ParsingAvailability

    public init(results: [ParseResult] = [], availability: ParsingAvailability = .available) {
        self.results = results
        self.availability = availability
    }

    public func prewarm() {}

    public func parse(_ text: String) async throws -> [ParseResult] {
        results
    }
}

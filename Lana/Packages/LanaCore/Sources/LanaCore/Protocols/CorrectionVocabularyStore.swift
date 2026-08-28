import Foundation

/// Un par término→categoría aprendido de una corrección del usuario
/// (ADR-0012). Se guardan las palabras que el usuario escribió, no el
/// concepto que generó el modelo — son las que va a volver a escribir.
///
/// `category` es `String`, no el enum cerrado de `LanaParsing` — este tipo
/// vive en `LanaCore` porque `SettingsFeature` (que solo puede depender de
/// `LanaCore`/`LanaDesign`) necesita mostrarlo y borrarlo (ADR-0014).
public struct CorrectionEntry: Sendable, Hashable, Codable, Identifiable {
    public var id: String {
        term
    }

    public let term: String
    public let category: String
    public let correctedAt: Date
    public var useCount: Int

    public init(term: String, category: String, correctedAt: Date = Date(), useCount: Int = 1) {
        self.term = term
        self.category = category
        self.correctedAt = correctedAt
        self.useCount = useCount
    }
}

/// Dónde vive el vocabulario aprendido. La implementación real (Core Data)
/// decide cómo persistirlo; `LanaParsing` solo necesita poder registrar
/// correcciones y leer las que importan para el prompt, y `SettingsFeature`
/// necesita poder mostrarlas y borrarlas.
///
/// Nombre fijado por el mismo patrón que `ExpenseStore` — "Store" es la
/// excepción explícita a la regla -ing/-able de Docs/CONVENTIONS.md para
/// protocolos de persistencia.
public protocol CorrectionVocabularyStore: Sendable { // swiftlint:disable:this protocol_naming_convention
    func record(term: String, category: String) async
    /// Las `limit` entradas más relevantes para inyectar al prompt: se
    /// conserva un número acotado porque cada una alarga el prompt y la
    /// latencia importa en la pantalla de captura (ADR-0012). Prioriza uso
    /// frecuente y luego recencia.
    func topEntries(limit: Int) async -> [CorrectionEntry]
    /// Todo el vocabulario, para mostrarlo en Ajustes.
    func allEntries() async -> [CorrectionEntry]
    /// Olvida una palabra específica.
    func delete(term: String) async
    /// Olvida todo lo aprendido.
    func deleteAll() async
}

/// Implementación en memoria para tests y `#Preview`.
public actor InMemoryCorrectionVocabularyStore: CorrectionVocabularyStore {
    private var entriesByTerm: [String: CorrectionEntry] = [:]

    public init(seed: [CorrectionEntry] = []) {
        for entry in seed {
            entriesByTerm[Self.normalize(entry.term)] = entry
        }
    }

    public func record(term: String, category: String) async {
        let key = Self.normalize(term)
        if var existing = entriesByTerm[key], existing.category == category {
            existing.useCount += 1
            entriesByTerm[key] = CorrectionEntry(
                term: existing.term,
                category: existing.category,
                correctedAt: Date(),
                useCount: existing.useCount)
        } else {
            entriesByTerm[key] = CorrectionEntry(term: term, category: category)
        }
    }

    public func topEntries(limit: Int) async -> [CorrectionEntry] {
        entriesByTerm.values
            .sorted { lhs, rhs in
                lhs.useCount == rhs.useCount ? lhs.correctedAt > rhs.correctedAt : lhs.useCount > rhs.useCount
            }
            .prefix(limit)
            .map(\.self)
    }

    public func allEntries() async -> [CorrectionEntry] {
        entriesByTerm.values.sorted { $0.useCount == $1.useCount ? $0.term < $1.term : $0.useCount > $1.useCount }
    }

    public func delete(term: String) async {
        entriesByTerm.removeValue(forKey: Self.normalize(term))
    }

    public func deleteAll() async {
        entriesByTerm.removeAll()
    }

    private static func normalize(_ term: String) -> String {
        term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

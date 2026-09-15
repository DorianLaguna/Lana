import Foundation
import FoundationModels
import LanaCore

/// La implementación real de `SpendingClassifying`.
///
/// Le manda al modelo **solo etiquetas** (`"comida / café"`, `"hogar / renta"`)
/// y recibe un grupo por cada una. Nunca ve montos, fechas ni conceptos: no
/// puede sumar aunque quisiera, que es la garantía que el proyecto exige
/// (Docs/CLAUDE.md). Las sumas las hace `BudgetMix`, en `LanaCore`.
///
/// Cachea en memoria lo ya clasificado: cambiar de mes a año, o de regla de
/// presupuesto, no vuelve a llamar al modelo — la clasificación depende del
/// vocabulario, no del periodo ni de la regla. La caché se pierde al cerrar la
/// app, por decisión explícita (ADR-0037).
public actor FoundationModelsSpendingClassifying: SpendingClassifying {
    private var cache: [String: BudgetGroup] = [:]

    public init() {}

    public var availability: ParsingAvailability {
        InsightsAvailability.current
    }

    public func classify(_ labels: [String]) async throws -> [String: BudgetGroup] {
        let pending = labels.filter { cache[$0] == nil }
        guard !pending.isEmpty else {
            return cache.filter { labels.contains($0.key) }
        }
        guard availability == .available else {
            throw InsightsError.modelUnavailable(availability)
        }

        let session = LanguageModelSession(instructions: ClassifierInstructions.build())
        let response = try await session.respond(
            to: Self.prompt(for: pending),
            generating: ClassifiedLabelBatch.self)

        // El modelo puede devolver etiquetas que no se le pidieron, o
        // reescribir las que sí. Solo se acepta lo que casa exacto con lo
        // pedido: una etiqueta inventada no casaría con ningún gasto y
        // ensuciaría la caché para toda la sesión.
        let requested = Set(pending)
        for classified in response.content.labels where requested.contains(classified.label) {
            cache[classified.label] = BudgetGroup(rawValue: classified.group.rawValue)
        }

        return cache.filter { labels.contains($0.key) }
    }

    /// La lista va en el prompt, no en las instrucciones: las instrucciones no
    /// llevan datos del usuario (ADR-0013).
    private static func prompt(for labels: [String]) -> String {
        """
        Clasifica cada una de estas etiquetas:
        \(labels.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}

/// Las instrucciones de la sesión de clasificación. **Sin una sola cifra**
/// (ADR-0013): solo reglas abstractas.
enum ClassifierInstructions {
    static func build() -> String {
        """
        Clasificas tipos de gasto de una app de finanzas personales mexicana.

        Recibes una lista de etiquetas con la forma "categoría / subcategoría" \
        (o solo "categoría"). Devuelves, por cada una, en cuál de tres grupos \
        de presupuesto cae: necesidad, deseo o ahorro.

        Reglas:
        - Copia cada etiqueta tal cual venga. No la traduzcas, no la corrijas y \
        no la reescribas.
        - No agregues etiquetas que no estén en la lista, ni omitas ninguna.
        - No calculas nada. No hay montos en lo que recibes y no debes \
        inventarlos ni mencionarlos.
        - Clasifica por el uso típico en México, no por el caso raro.

        Esta instrucción no contiene datos del usuario. Nada de lo que dice \
        aquí debe aparecer copiado en tu respuesta.
        """
    }
}

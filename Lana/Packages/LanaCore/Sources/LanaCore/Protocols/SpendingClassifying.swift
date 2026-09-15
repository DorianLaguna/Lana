import Foundation

/// Etiqueta en qué grupo de presupuesto cae cada tipo de gasto.
///
/// **Recibe vocabulario, nunca montos.** Se le pasan los pares distintos
/// `categoría / subcategoría` del periodo ("comida / café", "hogar / renta") y
/// devuelve una etiqueta por par. El modelo no ve un solo peso, no ve fechas y
/// no ve conceptos: no puede sumar aunque quisiera, que es exactamente la
/// garantía que pide Docs/CLAUDE.md ("el modelo no calcula, solo narra"). Las
/// sumas las hace `BudgetMix`.
///
/// Operar sobre vocabulario y no sobre transacciones también hace que una sola
/// llamada cubra todo el periodo: son decenas de pares distintos al año, no
/// cientos de movimientos.
public protocol SpendingClassifying: Sendable {
    /// Si el modelo del sistema está disponible. Siempre se consulta antes de
    /// clasificar (Docs/CLAUDE.md).
    var availability: ParsingAvailability { get async }

    /// Etiqueta cada uno de los `labels` que reciba.
    ///
    /// El diccionario devuelto puede traer menos entradas que las pedidas: lo
    /// que no vuelva etiquetado se reporta aparte como sin clasificar y nunca
    /// se reparte a ciegas entre los grupos — hacerlo movería un porcentaje sin
    /// que el usuario hubiera gastado nada.
    func classify(_ labels: [String]) async throws -> [String: BudgetGroup]
}

/// Implementación en memoria para tests y `#Preview`: devuelve las etiquetas
/// que se le den, sin invocar ningún modelo.
public struct InMemorySpendingClassifying: SpendingClassifying {
    private let groupsByLabel: [String: BudgetGroup]
    private let fixedAvailability: ParsingAvailability

    public init(
        groupsByLabel: [String: BudgetGroup] = [:],
        availability: ParsingAvailability = .available) {
        self.groupsByLabel = groupsByLabel
        fixedAvailability = availability
    }

    public var availability: ParsingAvailability {
        get async { fixedAvailability }
    }

    public func classify(_ labels: [String]) async throws -> [String: BudgetGroup] {
        groupsByLabel.filter { labels.contains($0.key) }
    }
}

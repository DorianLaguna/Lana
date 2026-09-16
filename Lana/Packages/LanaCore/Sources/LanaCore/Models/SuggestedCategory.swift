/// Las mismas once categorías cerradas que usa el parser
/// (`LanaParsing.ExpenseCategory`), duplicadas aquí a propósito: `LanaCore`
/// solo importa `Foundation` (Docs/CLAUDE.md) y ese enum usa `@Generable` de
/// `FoundationModels`. Esta copia es solo para poblar selectores en las
/// features (p. ej. el dropdown de categoría de un recurrente) — si la
/// lista cambia, hay que actualizar las dos.
public enum SuggestedCategory: String, Sendable, Hashable, CaseIterable, Codable, Identifiable {
    case comida
    case despensa
    case transporte
    case hogar
    case personal
    case ocio
    case salud
    case servicios
    case regalos
    case educacion
    case otro

    public var id: String {
        rawValue
    }

    /// El raw value es ASCII a propósito (sirve para comparar/guardar como
    /// texto libre en `Expense.category`) — esto es lo que sí lleva acento,
    /// para mostrar en un picker.
    public var displayName: String {
        switch self {
        case .educacion: "Educación"
        default: rawValue.capitalized
        }
    }
}

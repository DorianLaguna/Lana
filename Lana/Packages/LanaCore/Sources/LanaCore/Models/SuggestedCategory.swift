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

    /// Un índice fijo y único por caso (0 en adelante, por orden de
    /// declaración) — para pintar cada categoría cerrada con un color
    /// distinto de `LanaDesign.LanaColors.categoryRamp` sin depender de un
    /// hash, que con más categorías que colores en la rampa garantiza
    /// choques (dos categorías con el mismo tono, sin forma de
    /// diferenciarlas en una gráfica). Categorías libres que no coinciden
    /// con ningún caso — texto escrito a mano al capturar por voz — siguen
    /// cayendo al hash como respaldo, donde el choque es posible pero no
    /// garantizado.
    public var rampIndex: Int {
        // swiftlint:disable:next force_unwrapping
        Self.allCases.firstIndex(of: self)!
    }
}

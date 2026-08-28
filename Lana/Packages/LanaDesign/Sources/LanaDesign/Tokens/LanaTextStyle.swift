import SwiftUI

/// La escala tipográfica de la app — siempre ligada a Dynamic Type
/// (`Font.TextStyle` semántico), nunca un tamaño en puntos fijo
/// (Docs/.claude/skills/theming).
public enum LanaTextStyle: Sendable, CaseIterable {
    /// Montos grandes — hero del dashboard, pantalla de confirmación.
    case largeAmount
    case title
    case headline
    case body
    case caption

    public var font: Font {
        switch self {
        case .largeAmount: .system(.largeTitle, design: .rounded, weight: .bold)
        case .title: .system(.title2, weight: .semibold)
        case .headline: .system(.headline)
        case .body: .system(.body)
        case .caption: .system(.caption)
        }
    }
}

public extension Text {
    /// Aplica el estilo tipográfico de Lana a este `Text`.
    func lanaStyle(_ style: LanaTextStyle) -> Text {
        font(style.font)
    }
}

public extension View {
    /// Aplica el estilo tipográfico de Lana a cualquier vista.
    func lanaFont(_ style: LanaTextStyle) -> some View {
        font(style.font)
    }
}

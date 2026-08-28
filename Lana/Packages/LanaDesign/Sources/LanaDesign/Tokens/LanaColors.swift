import SwiftUI

/// Los colores con nombre por rol (Docs/.claude/skills/theming): `accent`,
/// nunca `blue`. Cuando el usuario cambia de tema el rol sigue siendo
/// correcto y el nombre sigue teniendo sentido. Los tres semánticos de
/// estado (`positive`, `warning`, `critical`) **no cambian con el tema** —
/// si el rojo de alerta variara, el usuario tendría que reaprender qué
/// significa cada color.
public struct LanaColors: Sendable, Equatable {
    public let accent: Color
    public let accentMuted: Color
    public let highlight: Color
    /// 12 tonos derivados del primario del tema, en orden fijo — el usuario
    /// no elige el color de una categoría (ADR-0006). Eran 8 hasta que
    /// `SuggestedCategory` llegó a 11 casos: con más categorías que tonos,
    /// dos categorías terminaban con el mismo color y no había forma de
    /// distinguirlas en una gráfica — 12 le da margen para crecer un poco
    /// más sin volver a chocar. "Otro" no tiene tono propio: usa
    /// `textSecondary`, porque no es una categoría real.
    public let categoryRamp: [Color]

    public let surface: Color
    public let surfaceRaised: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let separator: Color

    public let positive: Color
    public let warning: Color
    public let critical: Color

    public init(theme: LanaTheme, colorScheme: ColorScheme) {
        let isDark = colorScheme == .dark
        let palette = theme.palette

        accent = (isDark ? palette.primaryDark : palette.primaryLight).color
        accentMuted = accent.opacity(0.15)
        highlight = (isDark ? palette.secondaryDark : palette.secondaryLight).color
        categoryRamp = Self.categoryRamp(baseHue: theme.accentHue, isDark: isDark)

        surface = (isDark ? palette.surfaceDark : palette.surfaceLight).color
        surfaceRaised = (isDark ? palette.surfaceRaisedDark : palette.surfaceRaisedLight).color
        textPrimary = (isDark ? palette.textPrimaryDark : palette.textPrimaryLight).color
        textSecondary = (isDark ? palette.textSecondaryDark : palette.textSecondaryLight).color
        separator = (isDark ? palette.separatorDark : palette.separatorLight).color

        positive = (isDark ? Self.positiveDark : Self.positiveLight).color
        warning = (isDark ? Self.warningDark : Self.warningLight).color
        critical = (isDark ? Self.criticalDark : Self.criticalLight).color
    }

    private static func categoryRamp(baseHue: Double, isDark: Bool) -> [Color] {
        let saturation = 0.55
        let lightness = isDark ? 0.62 : 0.45
        return (0 ..< 12).map { step in
            RGBColor.hsl(hue: baseHue + Double(step) * 30, saturation: saturation, lightness: lightness).color
        }
    }

    // Los tres semánticos de estado sí siguen fijos en todos los temas
    // (ADR-0006, no tocado por ADR-0016) — verificados a 4.5:1 en
    // `LanaThemeContrastTests` contra la superficie de cada tema.
    static let positiveLight = RGBColor(hex: "#2E7D32")
    static let positiveDark = RGBColor(hex: "#35903A")
    static let warningLight = RGBColor(hex: "#966D09")
    static let warningDark = RGBColor(hex: "#B8860B")
    static let criticalLight = RGBColor(hex: "#C62828")
    static let criticalDark = RGBColor(hex: "#DB4E4E")
}

extension RGBColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

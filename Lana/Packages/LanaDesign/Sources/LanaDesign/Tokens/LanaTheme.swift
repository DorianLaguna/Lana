import Foundation

/// Los seis pares de color curados que el usuario puede elegir (ADR-0006).
/// Nunca un selector de color libre — dos colores al azar se pelean y
/// pueden caer debajo de 4.5:1 sin que el usuario lo note.
public enum LanaTheme: String, Sendable, CaseIterable, Identifiable, Codable {
    case cobalto
    case cempasuchil
    case jacaranda
    case nopal
    case bugambilia
    case obsidiana
    case ambar
    case zafiro

    public var id: String {
        rawValue
    }

    /// El nombre viene del mundo del usuario, no de la rueda de color.
    public var displayName: String {
        switch self {
        case .cobalto: "Cobalto"
        case .cempasuchil: "Cempasúchil"
        case .jacaranda: "Jacaranda"
        case .nopal: "Nopal"
        case .bugambilia: "Bugambilia"
        case .obsidiana: "Obsidiana"
        case .ambar: "Ámbar"
        case .zafiro: "Zafiro"
        }
    }

    public static var `default`: LanaTheme {
        .cobalto
    }
}

/// Los hex de cada tema, en variante clara y oscura. El hex base del ADR se
/// conserva donde ya cumplía 4.5:1 contra su superficie; donde no, se ajustó
/// la luminosidad manteniendo tono y saturación (misma técnica que usan los
/// sistemas de color de Material/Tailwind) hasta llegar exactamente a 4.5:1.
/// Verificado en `LanaThemeContrastTests`.
///
/// Superficie y texto también viven aquí, por tema — antes eran 10
/// constantes compartidas por los 6 temas (ADR-0016 revierte ese
/// invariante): Obsidiana necesita un fondo casi negro propio, forzado en
/// sus dos variantes, no el blanco/negro genérico que sí le sirve al resto.
struct ThemePalette: Sendable {
    let primaryLight: RGBColor
    let primaryDark: RGBColor
    let secondaryLight: RGBColor
    let secondaryDark: RGBColor
    let surfaceLight: RGBColor
    let surfaceDark: RGBColor
    let surfaceRaisedLight: RGBColor
    let surfaceRaisedDark: RGBColor
    let textPrimaryLight: RGBColor
    let textPrimaryDark: RGBColor
    let textSecondaryLight: RGBColor
    let textSecondaryDark: RGBColor
    let separatorLight: RGBColor
    let separatorDark: RGBColor
}

private extension ThemePalette {
    // Compartidos por los 5 temas que sí siguen el modo claro/oscuro del
    // sistema — Obsidiana es la única excepción (ver `LanaTheme.palette`).
    static let sharedSurfaceLight = RGBColor(hex: "#FFFFFF")
    static let sharedSurfaceDark = RGBColor(hex: "#121212")
    static let sharedSurfaceRaisedLight = RGBColor(hex: "#F5F5F7")
    static let sharedSurfaceRaisedDark = RGBColor(hex: "#1E1E22")
    static let sharedTextPrimaryLight = RGBColor(hex: "#1A1A1A")
    static let sharedTextPrimaryDark = RGBColor(hex: "#F2F2F2")
    static let sharedTextSecondaryLight = RGBColor(hex: "#6B6B6B")
    // #7F7F7F pasaba 4.5:1 contra `surfaceDark`, pero no contra
    // `surfaceRaisedDark` (#1E1E22) — 4.15:1, un hueco real que la suite
    // de contraste de antes nunca revisaba porque no probaba textSecondary
    // contra la superficie elevada. `LanaThemeContrastTests` lo agarra
    // ahora; este valor sí pasa ambas.
    static let sharedTextSecondaryDark = RGBColor(hex: "#8A8A8A")
    static let sharedSeparatorLight = RGBColor(hex: "#D1D1D6")
    static let sharedSeparatorDark = RGBColor(hex: "#38383A")

    /// Para los 5 temas que comparten superficie/texto con el modo del
    /// sistema — cero regresión visual contra los valores globales de antes.
    init(primaryLight: RGBColor, primaryDark: RGBColor, secondaryLight: RGBColor, secondaryDark: RGBColor) {
        self.init(
            primaryLight: primaryLight,
            primaryDark: primaryDark,
            secondaryLight: secondaryLight,
            secondaryDark: secondaryDark,
            surfaceLight: Self.sharedSurfaceLight,
            surfaceDark: Self.sharedSurfaceDark,
            surfaceRaisedLight: Self.sharedSurfaceRaisedLight,
            surfaceRaisedDark: Self.sharedSurfaceRaisedDark,
            textPrimaryLight: Self.sharedTextPrimaryLight,
            textPrimaryDark: Self.sharedTextPrimaryDark,
            textSecondaryLight: Self.sharedTextSecondaryLight,
            textSecondaryDark: Self.sharedTextSecondaryDark,
            separatorLight: Self.sharedSeparatorLight,
            separatorDark: Self.sharedSeparatorDark)
    }
}

extension LanaTheme {
    var palette: ThemePalette {
        switch self {
        case .cobalto:
            ThemePalette(
                primaryLight: RGBColor(hex: "#1B4FD8"),
                primaryDark: RGBColor(hex: "#4E79E9"),
                secondaryLight: RGBColor(hex: "#936F03"),
                secondaryDark: RGBColor(hex: "#F2B705"))
        case .cempasuchil:
            ThemePalette(
                primaryLight: RGBColor(hex: "#C84D0A"),
                primaryDark: RGBColor(hex: "#E8590C"),
                secondaryLight: RGBColor(hex: "#6D3B8E"),
                secondaryDark: RGBColor(hex: "#9E69C0"))
        case .jacaranda:
            ThemePalette(
                primaryLight: RGBColor(hex: "#6C4FB3"),
                primaryDark: RGBColor(hex: "#8971C2"),
                secondaryLight: RGBColor(hex: "#3C806A"),
                secondaryDark: RGBColor(hex: "#4FA88B"))
        case .nopal:
            ThemePalette(
                primaryLight: RGBColor(hex: "#2F7A4F"),
                primaryDark: RGBColor(hex: "#378E5C"),
                secondaryLight: RGBColor(hex: "#DB2866"),
                secondaryDark: RGBColor(hex: "#E0457B"))
        case .bugambilia:
            ThemePalette(
                primaryLight: RGBColor(hex: "#C2185B"),
                primaryDark: RGBColor(hex: "#E6377C"),
                secondaryLight: RGBColor(hex: "#9F6905"),
                secondaryDark: RGBColor(hex: "#F2A007"))
        case .obsidiana:
            // Fondo casi negro forzado en sus dos variantes — no el blanco
            // que le sirve al resto — porque Obsidiana siempre se ve
            // oscuro, sin importar el modo del sistema (ADR-0016). El
            // primario/secundario de la variante "clara" también se
            // adaptan: el tono que se diseñó para verse sobre blanco
            // (`#2B2B33`) no pasa 4.5:1 contra un fondo casi negro, así que
            // ambas variantes usan el mismo tono pensado para oscuro.
            ThemePalette(
                primaryLight: RGBColor(hex: "#7D7D91"),
                primaryDark: RGBColor(hex: "#7D7D91"),
                secondaryLight: RGBColor(hex: "#C9A227"),
                secondaryDark: RGBColor(hex: "#C9A227"),
                surfaceLight: RGBColor(hex: "#0A0A0C"),
                surfaceDark: RGBColor(hex: "#0A0A0C"),
                surfaceRaisedLight: RGBColor(hex: "#151517"),
                surfaceRaisedDark: RGBColor(hex: "#151517"),
                textPrimaryLight: RGBColor(hex: "#F2F2F2"),
                textPrimaryDark: RGBColor(hex: "#F2F2F2"),
                textSecondaryLight: RGBColor(hex: "#8C8C99"),
                textSecondaryDark: RGBColor(hex: "#8C8C99"),
                separatorLight: RGBColor(hex: "#38383A"),
                separatorDark: RGBColor(hex: "#38383A"))
        case .ambar:
            // Mismo concepto que Obsidiana — fondo casi negro forzado en
            // sus dos variantes — con un acento propio en vez de repetir
            // el mismo gris (pedido explícito del usuario: más de un tema
            // oscuro, no solo Obsidiana).
            ThemePalette(
                primaryLight: RGBColor(hex: "#D99B3D"),
                primaryDark: RGBColor(hex: "#D99B3D"),
                secondaryLight: RGBColor(hex: "#3D97A6"),
                secondaryDark: RGBColor(hex: "#3D97A6"),
                surfaceLight: RGBColor(hex: "#0A0A0C"),
                surfaceDark: RGBColor(hex: "#0A0A0C"),
                surfaceRaisedLight: RGBColor(hex: "#151517"),
                surfaceRaisedDark: RGBColor(hex: "#151517"),
                textPrimaryLight: RGBColor(hex: "#F2F2F2"),
                textPrimaryDark: RGBColor(hex: "#F2F2F2"),
                textSecondaryLight: RGBColor(hex: "#8C8C99"),
                textSecondaryDark: RGBColor(hex: "#8C8C99"),
                separatorLight: RGBColor(hex: "#38383A"),
                separatorDark: RGBColor(hex: "#38383A"))
        case .zafiro:
            ThemePalette(
                primaryLight: RGBColor(hex: "#5C7EE8"),
                primaryDark: RGBColor(hex: "#5C7EE8"),
                secondaryLight: RGBColor(hex: "#D9825C"),
                secondaryDark: RGBColor(hex: "#D9825C"),
                surfaceLight: RGBColor(hex: "#0A0A0C"),
                surfaceDark: RGBColor(hex: "#0A0A0C"),
                surfaceRaisedLight: RGBColor(hex: "#151517"),
                surfaceRaisedDark: RGBColor(hex: "#151517"),
                textPrimaryLight: RGBColor(hex: "#F2F2F2"),
                textPrimaryDark: RGBColor(hex: "#F2F2F2"),
                textSecondaryLight: RGBColor(hex: "#8C8C99"),
                textSecondaryDark: RGBColor(hex: "#8C8C99"),
                separatorLight: RGBColor(hex: "#38383A"),
                separatorDark: RGBColor(hex: "#38383A"))
        }
    }

    /// El hue base (0-360) del primario, ancla de la rampa de categorías
    /// (`LanaColors.categoryRamp`) — mismo tono en claro y oscuro.
    var accentHue: Double {
        palette.primaryLight.hslHue
    }

    /// `true` para los temas que fuerzan fondo casi negro en sus dos
    /// variantes (Obsidiana, Ámbar, Zafiro) — se deriva de la paleta en vez
    /// de listar casos a mano, así que un tema nuevo con el mismo patrón
    /// queda cubierto automáticamente por `ContentView`
    /// (`.preferredColorScheme`) y por `LanaThemeContrastTests` (que excluye
    /// la variante "clara" de los semánticos fijos para estos temas — ver
    /// ADR-0016/ADR-0017).
    public var forcesDarkAppearance: Bool {
        palette.surfaceLight == palette.surfaceDark
    }
}

import Foundation

/// Los temas curados que el usuario puede elegir (ADR-0006, ADR-0044).
/// Nunca un selector de color libre — dos colores al azar se pelean y
/// pueden caer debajo del contraste mínimo sin que el usuario lo note.
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

/// Lo único que cambia de un tema a otro desde el rediseño (ADR-0044): el
/// acento. Superficies y tinta son las mismas para todos — en oscuro, las del
/// handoff; en claro, su análogo — porque la jerarquía la da el fondo, y un
/// fondo distinto por tema volvía a hacer que todo pesara distinto.
///
/// El acento se guarda en tres formas porque un solo hex no alcanza para los
/// ocho temas:
/// - `fill`: el color tal cual lo eligió diseño. Rellena botones, barras, el
///   micrófono y el swatch del selector.
/// - `textDark`/`textLight`: el mismo tono con la luminosidad ajustada hasta
///   4.5:1 contra las superficies de cada modo. Zafiro (`#1F4FA8`) y
///   Obsidiana (`#2A2C33`) son rellenos preciosos y texto ilegible sobre casi
///   negro; aquí se separan en vez de sacrificar uno de los dos.
/// Verificado en `LanaThemeContrastTests`.
struct ThemePalette: Sendable {
    let fill: RGBColor
    let textDark: RGBColor
    let textLight: RGBColor
    /// El segundo tono de los degradados decorativos (la barra de Mes, la
    /// onda de voz). Nunca texto.
    let gradientEnd: RGBColor
    /// Los temas "siempre oscuro": ignoran el modo del sistema (ADR-0016).
    let forcesDark: Bool
}

public extension LanaTheme {
    internal var palette: ThemePalette {
        switch self {
        case .cobalto:
            ThemePalette(
                fill: RGBColor(hex: "#5B7CFA"),
                textDark: RGBColor(hex: "#5B7CFA"),
                textLight: RGBColor(hex: "#315AF9"),
                gradientEnd: RGBColor(hex: "#8A6CF0"),
                forcesDark: false)
        case .cempasuchil:
            ThemePalette(
                fill: RGBColor(hex: "#F08A4B"),
                textDark: RGBColor(hex: "#F08A4B"),
                textLight: RGBColor(hex: "#B24D0F"),
                gradientEnd: RGBColor(hex: "#D8578F"),
                forcesDark: false)
        case .jacaranda:
            ThemePalette(
                fill: RGBColor(hex: "#8A6CF0"),
                textDark: RGBColor(hex: "#8E71F0"),
                textLight: RGBColor(hex: "#6A45E8"),
                gradientEnd: RGBColor(hex: "#D8578F"),
                forcesDark: false)
        case .nopal:
            ThemePalette(
                fill: RGBColor(hex: "#4FD08A"),
                textDark: RGBColor(hex: "#4FD08A"),
                textLight: RGBColor(hex: "#217A49"),
                gradientEnd: RGBColor(hex: "#5B7CFA"),
                forcesDark: false)
        case .bugambilia:
            ThemePalette(
                fill: RGBColor(hex: "#D8578F"),
                textDark: RGBColor(hex: "#D8578F"),
                textLight: RGBColor(hex: "#C42E6F"),
                gradientEnd: RGBColor(hex: "#F08A4B"),
                forcesDark: false)
        case .obsidiana:
            ThemePalette(
                fill: RGBColor(hex: "#2A2C33"),
                textDark: RGBColor(hex: "#7F8496"),
                textLight: RGBColor(hex: "#7F8496"),
                gradientEnd: RGBColor(hex: "#7F8496"),
                forcesDark: true)
        case .ambar:
            ThemePalette(
                fill: RGBColor(hex: "#C9962E"),
                textDark: RGBColor(hex: "#C9962E"),
                textLight: RGBColor(hex: "#C9962E"),
                gradientEnd: RGBColor(hex: "#F08A4B"),
                forcesDark: true)
        case .zafiro:
            ThemePalette(
                fill: RGBColor(hex: "#1F4FA8"),
                textDark: RGBColor(hex: "#5183DF"),
                textLight: RGBColor(hex: "#5183DF"),
                gradientEnd: RGBColor(hex: "#8A6CF0"),
                forcesDark: true)
        }
    }

    /// `true` para los temas que se ven oscuros sin importar el sistema
    /// (Obsidiana, Ámbar, Zafiro). `MainTabView` lo usa para
    /// `.preferredColorScheme`, que cubre el chrome que Lana no dibuja
    /// (barra de estado, teclado).
    var forcesDarkAppearance: Bool {
        palette.forcesDark
    }

    /// La línea bajo el selector de tema en Ajustes: "Zafiro · siempre oscuro"
    /// o "Cobalto · sigue tu iPhone".
    var appearanceDescription: String {
        forcesDarkAppearance ? "\(displayName) · siempre oscuro" : "\(displayName) · sigue tu iPhone"
    }
}

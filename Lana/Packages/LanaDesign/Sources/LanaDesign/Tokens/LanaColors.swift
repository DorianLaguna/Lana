import SwiftUI

/// Los colores con nombre por rol (ADR-0044, `.claude/skills/theming`):
/// `accent`, nunca `blue`. Cuando el usuario cambia de tema el rol sigue
/// siendo correcto.
///
/// Reglas que estos tokens encarnan:
/// - **No hay rojo.** Ni para gastos ni para borrar; el rojo del sistema solo
///   aparece durante un swipe destructivo, y ese lo pone iOS, no Lana.
/// - **Un acento por pantalla.** `attention` marca lo que reclama acción;
///   `accent` lo que se puede tocar.
/// - **Las categorías no tienen color propio.** Van en `ink28`, y solo la que
///   domina usa `attention`.
public struct LanaColors: Sendable, Equatable {
    // MARK: Acento (cambia con el tema)

    /// Texto y glifos tocables: "Ver el mes", "Editar", la pestaña activa.
    /// Garantiza 4.5:1 contra `bg`, `surface` y `surface2`.
    public let accent: Color
    /// Relleno de botones, barras de progreso, el micrófono y el swatch del
    /// tema. Es el hex que eligió diseño; puede no servir como texto.
    public let accentFill: Color
    /// El texto o glifo que va encima de `accentFill`: blanco cuando da 3:1
    /// (los botones son semibold ≥15 pt), `bg` cuando no.
    public let onAccent: Color
    /// `accentFill` al 10 %: fondo de una entrada que invita (Apple Pay sin
    /// configurar).
    public let accentSoft: Color
    /// `accentFill` al 8 %: fondo de las sugerencias del Análisis.
    public let accentSofter: Color
    /// `accentFill` al 30 %: borde de las sugerencias del Análisis.
    public let accentBorder: Color
    /// `accentFill` al 12 %: resalte de una fila recién guardada.
    public let accentHighlight: Color
    /// `accentFill` al 45 %: sombra del micrófono.
    public let accentShadow: Color
    /// El segundo tono de los degradados decorativos. Nunca texto.
    public let highlight: Color
    /// Transición: el fondo al 15 % que usaban los estados activos antes del
    /// rediseño.
    public let accentMuted: Color
    /// Transición: las pantallas que todavía dibujan una rampa por categoría
    /// la reciben en gris neutro (`ink28`), que es lo que pide el rediseño.
    /// Se elimina cuando la última gráfica migra a `ProportionBar`.
    public let categoryRamp: [Color]

    // MARK: Superficies

    /// Fondo de toda pantalla. Casi negro, no negro puro.
    public let bg: Color
    /// Tarjetas y agrupaciones sobre el fondo.
    public let surface: Color
    /// Chips, pistas de barras, botón secundario.
    public let surface2: Color
    /// Segmento activo, avatar, chip sobre `surface`.
    public let surface3: Color
    /// La tarjeta apagada de una tarjeta bancaria sin deuda.
    public let surfaceDim: Color
    /// Separadores dentro de una tarjeta.
    public let hairline: Color
    /// Separadores de listas sobre el fondo.
    public let hairlineStrong: Color
    /// El fondo translúcido de la barra de pestañas (se monta sobre
    /// `.ultraThinMaterial`).
    public let tabBarTint: Color
    /// El borde de la barra de pestañas.
    public let tabBarBorder: Color
    /// El borde punteado de "+ Nueva lista compartida".
    public let dashedBorder: Color
    /// El asa de una hoja.
    public let handle: Color

    // MARK: Tinta

    /// Texto principal y cifras.
    public let ink: Color
    /// Texto de apoyo con peso.
    public let ink70: Color
    /// El cuerpo de la guía de Apple Pay.
    public let ink60: Color
    /// La descripción del tema elegido.
    public let ink55: Color
    /// Etiquetas, encabezados de sección.
    public let ink50: Color
    /// Los decimales de la cifra héroe.
    public let ink45: Color
    /// Subtítulos de fila, pestañas inactivas. Solo texto de apoyo ≥12.5 pt.
    public let ink42: Color
    /// Texto deshabilitado, "Sin deuda".
    public let ink35: Color
    /// Etiquetas de eje, pie legal, la palabra en curso del dictado.
    public let ink30: Color
    /// Barras de categoría que no dominan.
    public let ink28: Color

    // MARK: Semánticos (fijos en todos los temas)

    /// Por revisar, pendientes, el mes más caro, la categoría que domina.
    public let attention: Color
    /// `attention` al 13 %: fondo de "Por revisar" y del ritmo excedido.
    public let attentionSoft: Color
    /// `attention` al 16 %: chip de duda en un borrador.
    public let attentionChip: Color
    /// `attention` al 10 %: tarjeta de un recurrente pendiente, advertencias.
    public let attentionSofter: Color
    /// `attention` al 25 %: borde de un recurrente pendiente.
    public let attentionBorder: Color
    /// Ingresos, saldos a favor, estados correctos.
    public let positive: Color

    public init(theme: LanaTheme, colorScheme: ColorScheme) {
        let palette = theme.palette
        let isDark = colorScheme == .dark || palette.forcesDark
        let neutrals = isDark ? NeutralPalette.dark : NeutralPalette.light

        accent = (isDark ? palette.textDark : palette.textLight).color
        accentFill = palette.fill.color
        onAccent = palette.fill.preferredForeground.color
        accentSoft = palette.fill.color.opacity(0.10)
        accentSofter = palette.fill.color.opacity(0.08)
        accentBorder = palette.fill.color.opacity(0.30)
        accentHighlight = palette.fill.color.opacity(0.12)
        accentShadow = palette.fill.color.opacity(0.45)
        highlight = palette.gradientEnd.color
        accentMuted = palette.fill.color.opacity(0.15)

        bg = neutrals.bg.color
        surface = neutrals.surface.color
        surface2 = neutrals.surface2.color
        surface3 = neutrals.surface3.color
        surfaceDim = neutrals.surfaceDim.color
        hairline = neutrals.inkBase.color.opacity(0.06)
        hairlineStrong = neutrals.inkBase.color.opacity(0.08)
        tabBarTint = neutrals.tabBar.color.opacity(0.92)
        tabBarBorder = neutrals.inkBase.color.opacity(0.07)
        dashedBorder = neutrals.inkBase.color.opacity(0.14)
        handle = neutrals.inkBase.color.opacity(0.18)

        ink = neutrals.ink.color
        ink70 = neutrals.ink(.ink70)
        ink60 = neutrals.ink(.ink60)
        ink55 = neutrals.ink(.ink55)
        ink50 = neutrals.ink(.ink50)
        ink45 = neutrals.ink(.ink45)
        ink42 = neutrals.ink(.ink42)
        ink35 = neutrals.ink(.ink35)
        ink30 = neutrals.ink(.ink30)
        ink28 = neutrals.ink(.ink28)
        categoryRamp = Array(repeating: ink28, count: 12)

        let attentionBase = isDark ? Self.attentionDark : Self.attentionLight
        attention = attentionBase.color
        attentionSoft = Self.attentionDark.color.opacity(0.13)
        attentionChip = Self.attentionDark.color.opacity(0.16)
        attentionSofter = Self.attentionDark.color.opacity(0.10)
        attentionBorder = Self.attentionDark.color.opacity(0.25)
        positive = (isDark ? Self.positiveDark : Self.positiveLight).color
    }

    static let attentionDark = RGBColor(hex: "#F08A4B")
    static let attentionLight = RGBColor(hex: "#B24D0F")
    static let positiveDark = RGBColor(hex: "#4FD08A")
    static let positiveLight = RGBColor(hex: "#217A49")
}

/// Los niveles de tinta con opacidad. Cada uno trae su opacidad en oscuro
/// (sobre blanco) y en claro (sobre casi negro), elegidas para que el
/// contraste resultante sea el mismo en los dos modos.
enum InkLevel: CaseIterable {
    case ink70
    case ink60
    case ink55
    case ink50
    case ink45
    case ink42
    case ink35
    case ink30
    case ink28

    var darkOpacity: Double {
        switch self {
        case .ink70: 0.70
        case .ink60: 0.60
        case .ink55: 0.55
        case .ink50: 0.50
        case .ink45: 0.45
        case .ink42: 0.42
        case .ink35: 0.35
        case .ink30: 0.30
        case .ink28: 0.28
        }
    }

    var lightOpacity: Double {
        switch self {
        case .ink70: 0.74
        case .ink60: 0.66
        case .ink55: 0.62
        case .ink50: 0.58
        case .ink45: 0.54
        case .ink42: 0.52
        case .ink35: 0.46
        case .ink30: 0.40
        case .ink28: 0.36
        }
    }

    /// El contraste que este nivel tiene que garantizar. `nil` para los
    /// niveles decorativos o de texto deshabilitado, que WCAG exime.
    var minimumContrast: Double? {
        switch self {
        case .ink70, .ink60, .ink55, .ink50: 4.5
        case .ink45, .ink42: 3.0
        case .ink35, .ink30, .ink28: nil
        }
    }
}

/// Superficies y tinta de un modo. Una sola para todos los temas.
struct NeutralPalette: Sendable {
    let bg: RGBColor
    let surface: RGBColor
    let surface2: RGBColor
    let surface3: RGBColor
    let surfaceDim: RGBColor
    let tabBar: RGBColor
    let ink: RGBColor
    /// Sobre qué color se aplican las opacidades de tinta.
    let inkBase: RGBColor
    let isDark: Bool

    static let dark = NeutralPalette(
        bg: RGBColor(hex: "#0B0B0D"),
        surface: RGBColor(hex: "#15161A"),
        surface2: RGBColor(hex: "#1C1D22"),
        surface3: RGBColor(hex: "#2A2C33"),
        surfaceDim: RGBColor(hex: "#111216"),
        tabBar: RGBColor(hex: "#16171C"),
        ink: RGBColor(hex: "#F5F6F8"),
        inkBase: RGBColor(hex: "#FFFFFF"),
        isDark: true)

    static let light = NeutralPalette(
        bg: RGBColor(hex: "#F4F5F7"),
        surface: RGBColor(hex: "#FFFFFF"),
        surface2: RGBColor(hex: "#ECEDF0"),
        surface3: RGBColor(hex: "#E1E2E7"),
        surfaceDim: RGBColor(hex: "#F8F8FA"),
        tabBar: RGBColor(hex: "#FAFAFC"),
        ink: RGBColor(hex: "#0B0B0D"),
        inkBase: RGBColor(hex: "#0B0B0D"),
        isDark: false)

    func opacity(for level: InkLevel) -> Double {
        isDark ? level.darkOpacity : level.lightOpacity
    }

    func ink(_ level: InkLevel) -> Color {
        inkBase.color.opacity(opacity(for: level))
    }
}

extension RGBColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// Este color con opacidad `alpha`, ya mezclado sobre `background` — lo
    /// que de verdad llega al ojo, para medir contraste de la tinta con
    /// opacidad.
    func composited(alpha: Double, over background: RGBColor) -> RGBColor {
        RGBColor(
            red: red * alpha + background.red * (1 - alpha),
            green: green * alpha + background.green * (1 - alpha),
            blue: blue * alpha + background.blue * (1 - alpha))
    }

    /// Blanco si da 3:1 sobre este color; si no, el `bg` oscuro. 3:1 porque
    /// todo texto sobre un relleno de acento es semibold de 13 pt o más.
    var preferredForeground: RGBColor {
        let white = RGBColor(hex: "#FFFFFF")
        return white.contrastRatio(with: self) >= 3 ? white : NeutralPalette.dark.bg
    }
}

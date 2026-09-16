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
    /// `accent` al 10 % (12 % en claro): fondo de una entrada que invita
    /// (Apple Pay sin configurar).
    public let accentSoft: Color
    /// `accent` al 8 % (10 % en claro): fondo de las sugerencias del Análisis.
    public let accentSofter: Color
    /// `accent` al 30 % (34 % en claro): borde de las sugerencias del Análisis.
    public let accentBorder: Color
    /// `accent` al 12 % (14 % en claro): resalte de una fila recién guardada.
    public let accentHighlight: Color
    /// `accentFill` al 45 %: sombra del micrófono.
    public let accentShadow: Color
    /// El segundo tono de los degradados decorativos. Nunca texto.
    public let highlight: Color

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
    /// La etiqueta y el icono de una pestaña inactiva: `ink60`, porque la
    /// etiqueta es de 10.5 pt y necesita 4.5:1 contra la barra ya compuesta.
    public let tabBarInactive: Color
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
    /// Subtítulos de fila. Solo texto de apoyo ≥12.5 pt.
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
    /// `attention` al 13 % (14 % en claro): fondo de "Por revisar" y del ritmo
    /// excedido.
    public let attentionSoft: Color
    /// `attention` al 16 %: chip de duda en un borrador.
    public let attentionChip: Color
    /// `attention` al 10 % (12 % en claro): tarjeta de un recurrente
    /// pendiente, advertencias.
    public let attentionSofter: Color
    /// `attention` al 25 % (34 % en claro): borde de un recurrente pendiente.
    public let attentionBorder: Color
    /// Ingresos, saldos a favor, estados correctos.
    public let positive: Color
    /// Las seis barras de la onda de voz, de izquierda a derecha: del acento a
    /// `attention` pasando por dos violetas. Decorativo, nunca texto.
    public let voiceWave: [Color]

    public init(theme: LanaTheme, colorScheme: ColorScheme) {
        let palette = theme.palette
        let isDark = colorScheme == .dark || palette.forcesDark
        let neutrals = isDark ? NeutralPalette.dark : NeutralPalette.light

        accent = (isDark ? palette.textDark : palette.textLight).color
        accentFill = palette.fill.color
        onAccent = palette.fill.preferredForeground.color
        // Los tintes salen del acento de texto, no del relleno: es el tono que
        // ya está ajustado a cada modo. Del relleno, Obsidiana (igual a
        // `surface3`) no se distinguía del fondo en oscuro, y un relleno claro
        // como Nopal apenas pintaba sobre blanco.
        let accentTint = isDark ? palette.textDark : palette.textLight
        let accentOpacities = isDark ? AccentTints.dark : AccentTints.light
        accentSoft = accentTint.color.opacity(accentOpacities.soft)
        accentSofter = accentTint.color.opacity(accentOpacities.softer)
        accentBorder = accentTint.color.opacity(accentOpacities.border)
        accentHighlight = accentTint.color.opacity(accentOpacities.highlight)
        accentShadow = palette.fill.color.opacity(0.45)
        highlight = palette.gradientEnd.color

        bg = neutrals.bg.color
        surface = neutrals.surface.color
        surface2 = neutrals.surface2.color
        surface3 = neutrals.surface3.color
        surfaceDim = neutrals.surfaceDim.color
        hairline = neutrals.inkBase.color.opacity(0.06)
        hairlineStrong = neutrals.inkBase.color.opacity(0.08)
        tabBarTint = neutrals.tabBar.color.opacity(NeutralPalette.tabBarTintOpacity)
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
        tabBarInactive = neutrals.ink(NeutralPalette.tabBarInactiveInk)

        let attentionBase = isDark ? Self.attentionDark : Self.attentionLight
        attention = attentionBase.color
        let attentionOpacities = isDark ? AttentionTints.dark : AttentionTints.light
        attentionSoft = attentionBase.color.opacity(attentionOpacities.soft)
        attentionChip = attentionBase.color.opacity(attentionOpacities.chip)
        attentionSofter = attentionBase.color.opacity(attentionOpacities.softer)
        attentionBorder = attentionBase.color.opacity(attentionOpacities.border)
        positive = (isDark ? Self.positiveDark : Self.positiveLight).color
        voiceWave = [
            accentFill,
            accentFill,
            Self.waveViolet.color,
            Self.waveMagenta.color,
            attention,
            attention
        ]
    }

    static let waveViolet = RGBColor(hex: "#7B6CF5")
    static let waveMagenta = RGBColor(hex: "#A55FE0")

    static let attentionDark = RGBColor(hex: "#F08A4B")
    /// Más oscuro que el `#B24D0F` original: con aquel, el texto en
    /// `attention` sobre su propio chip no llegaba a 4.5:1 en claro.
    static let attentionLight = RGBColor(hex: "#96410D")
    static let positiveDark = RGBColor(hex: "#4FD08A")
    static let positiveLight = RGBColor(hex: "#217A49")
}

/// Las opacidades de los fondos teñidos, por modo. En oscuro son las del
/// handoff. En claro un tinte sobre blanco rinde menos, así que suben hasta
/// separarse del fondo más o menos lo mismo que en oscuro, sin que el texto
/// que va encima baje de 4.5:1 (`LanaThemeContrastTests`).
struct AttentionTints: Sendable {
    let soft: Double
    let chip: Double
    let softer: Double
    let border: Double

    static let dark = AttentionTints(soft: 0.13, chip: 0.16, softer: 0.10, border: 0.25)
    static let light = AttentionTints(soft: 0.14, chip: 0.16, softer: 0.12, border: 0.34)
}

/// Ver `AttentionTints`.
struct AccentTints: Sendable {
    let soft: Double
    let softer: Double
    let border: Double
    let highlight: Double

    static let dark = AccentTints(soft: 0.10, softer: 0.08, border: 0.30, highlight: 0.12)
    static let light = AccentTints(soft: 0.12, softer: 0.10, border: 0.34, highlight: 0.14)
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

    /// La opacidad de `tabBar` sobre el material de la barra de pestañas.
    static let tabBarTintOpacity = 0.92
    /// El nivel de tinta de una pestaña inactiva.
    static let tabBarInactiveInk = InkLevel.ink60

    /// La barra de pestañas como llega al ojo: `tabBar` al 92 % sobre `bg`.
    /// El material de abajo desenfoca el fondo, así que `bg` es su mejor
    /// aproximación sin un contexto de renderizado.
    var composedTabBar: RGBColor {
        tabBar.composited(alpha: Self.tabBarTintOpacity, over: bg)
    }

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

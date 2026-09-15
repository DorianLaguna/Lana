import Foundation

/// La única escala de espaciado válida en toda la app (ADR-0044). Nació en
/// pasos de 4 pt (`xs`…`xxl`); el rediseño agrega los intermedios que usa de
/// verdad y los nombra por su valor (`p10` son 10 pt) en vez de redondearlos.
/// Un `.padding(17)` en una vista sigue siendo un bug: si el valor no está
/// aquí, falta un caso, no un número.
public enum Space: CGFloat, Sendable, CaseIterable {
    case p2 = 2
    case p3 = 3
    case xs = 4
    case p5 = 5
    case p6 = 6
    case p7 = 7
    case sm = 8
    case p9 = 9
    case p10 = 10
    case p11 = 11
    case p12 = 12
    case p13 = 13
    case p14 = 14
    case p15 = 15
    case md = 16
    case p18 = 18
    case p20 = 20
    case p22 = 22
    case lg = 24
    case p26 = 26
    case p28 = 28
    case p30 = 30
    case xl = 32
    case p34 = 34
    case p38 = 38
    case p40 = 40
    case p44 = 44
    case xxl = 48
}

/// Medidas de layout con nombre: márgenes de pantalla, alturas fijas de
/// componentes y el colchón al final del scroll.
public enum LanaMetrics {
    /// Margen lateral de pantalla.
    public static let screenMargin: CGFloat = 20
    /// Margen lateral del onboarding.
    public static let onboardingMargin: CGFloat = 24
    /// Inicio del contenido bajo el notch cuando no hay encabezado propio.
    public static let contentTop: CGFloat = 62
    /// Inicio del contenido bajo el notch con encabezado.
    public static let contentTopWithHeader: CGFloat = 56
    /// Colchón al final del scroll para que la barra de pestañas no tape nada.
    public static let scrollTail: CGFloat = 120
    /// El colchón de Hoy, un poco mayor.
    public static let scrollTailToday: CGFloat = 132
    /// El colchón de pantallas sin barra (Ajustes).
    public static let scrollTailNoTabBar: CGFloat = 60
    /// Alto de la barra de pestañas.
    public static let tabBarHeight: CGFloat = 66
    /// Separación de la barra respecto a los bordes laterales.
    public static let tabBarSideInset: CGFloat = 12
    /// Separación de la barra respecto al borde inferior.
    public static let tabBarBottomInset: CGFloat = 24
    /// Diámetro del botón de micrófono en la barra.
    public static let micDiameter: CGFloat = 48
    /// Ancho de la ranura central del micrófono.
    public static let micSlot: CGFloat = 56
    /// Icono de pestaña.
    public static let tabIcon: CGFloat = 20
    /// Botón de terminar el dictado.
    public static let stopButton: CGFloat = 76
    /// Glifo cuadrado dentro del botón de terminar.
    public static let stopGlyph: CGFloat = 22
    /// Avatar en el encabezado de Hoy.
    public static let avatarSmall: CGFloat = 32
    /// Avatar en la tarjeta de cuenta de Ajustes.
    public static let avatarLarge: CGFloat = 44
    /// Avatar apilado en una lista compartida.
    public static let avatarStacked: CGFloat = 26
    /// Cuánto se enciman los avatares apilados.
    public static let avatarOverlap: CGFloat = -8
    /// Círculo con el número de "Por revisar".
    public static let badge: CGFloat = 26
    /// Swatch del selector de tema.
    public static let themeSwatch: CGFloat = 34
    /// Icono de un estado vacío.
    public static let emptyStateIcon: CGFloat = 40
    /// Ancho máximo del texto de un estado vacío.
    public static let emptyStateMaxWidth: CGFloat = 280
    /// Área mínima de toque.
    public static let minTouchTarget: CGFloat = 44
    /// Alto mínimo de una fila de lista.
    public static let minRowHeight: CGFloat = 48
    /// Alto de un chip; su área de toque se amplía hasta `minTouchTarget`.
    public static let chipHeight: CGFloat = 34
    /// Rectángulo de color de una tarjeta bancaria.
    public static let cardSwatchWidth: CGFloat = 34
    /// Alto del rectángulo de color de una tarjeta bancaria.
    public static let cardSwatchHeight: CGFloat = 22
    /// Barra vertical junto a cada tarjeta en "Esta quincena".
    public static let cardTickWidth: CGFloat = 4
    /// Alto de esa barra vertical.
    public static let cardTickHeight: CGFloat = 16
    /// Punto de estado (encabezado de revisión, leyendas).
    public static let dot: CGFloat = 7
    /// Grosor de un separador.
    public static let hairline: CGFloat = 1
    /// Grosor del borde de un swatch activo o de un avatar apilado.
    public static let outline: CGFloat = 2
    /// Asa de hoja: ancho.
    public static let handleWidth: CGFloat = 38
    /// Asa de hoja: alto.
    public static let handleHeight: CGFloat = 4
    /// Alto de las barras de la vista anual.
    public static let yearBarsHeight: CGFloat = 96
    /// Alto de un mes sin movimiento en la vista anual, como fracción.
    public static let yearBarEmptyFraction: CGFloat = 0.08
    /// Onda de voz: alto máximo.
    public static let waveformHeight: CGFloat = 44
    /// Onda de voz: ancho de barra.
    public static let waveformBarWidth: CGFloat = 4
    /// Botón circular de enviar en el campo de pregunta.
    public static let sendButton: CGFloat = 28
    /// Flecha del mapeo Wallet → Lana: ancho.
    public static let mappingArrowWidth: CGFloat = 18
    /// Segmento de progreso de la guía.
    public static let guideProgressHeight: CGFloat = 3
    /// Barra más fina: categorías de una tarjeta.
    public static let barThin: CGFloat = 3
    /// Barra de categoría.
    public static let barRegular: CGFloat = 4
    /// Barra bajo la cifra héroe y de límite.
    public static let barMedium: CGFloat = 6
    /// Barra de Gastado/Ingresos en Mes.
    public static let barThick: CGFloat = 8
    /// Barra apilada del Análisis.
    public static let barStacked: CGFloat = 10
}

import SwiftUI

/// La escala tipográfica de la app (ADR-0044). SF Pro con los tamaños del
/// rediseño, **escalados con Dynamic Type** vía `@ScaledMetric` relativo a un
/// `Font.TextStyle`: el punto de partida es el del diseño y de ahí crece con
/// la preferencia del usuario. Las cifras usan dígitos tabulares siempre.
///
/// Si una vista necesita un tamaño que no está aquí, la pregunta es qué rol
/// le falta a la escala, no qué número poner.
public enum LanaTextStyle: Sendable, CaseIterable {
    // MARK: Cifras

    /// 56 pt — la cifra de Hoy. Limitada a XXL para no romper el layout.
    case heroAmount
    /// 26 pt — el `$` y los decimales que acompañan a `heroAmount`.
    case heroFraction
    /// 44 pt — la cifra que abre una pantalla de detalle.
    case screenAmount
    /// 42 pt — "Debes en total", "Te deben".
    case totalAmount
    /// 28 pt — Gastado/Ingresos en Mes, "Todo saldado".
    case blockAmount
    /// 24 pt — el monto de un borrador.
    case draftAmount
    /// 22 pt — "A pagar de tarjetas".
    case cardAmount
    /// 19 pt — Para el corte / Después del corte, un pendiente.
    case statAmount
    /// 16.5 pt semibold — la deuda de una tarjeta, un valor de tabla.
    case rowAmountStrong
    /// 16 pt medium — el monto de una fila de movimiento.
    case rowAmount

    // MARK: Texto

    /// 31 pt — el título de un paso de la guía.
    case guideTitle
    /// 26 pt medium — la transcripción en vivo.
    case transcript
    /// 19 pt semibold — el mes en Hoy, el título de un estado vacío.
    case screenTitle
    /// 19 pt regular — el resumen del Análisis.
    case summary
    /// 17 pt semibold — título de hoja, navegador de mes.
    case sheetTitle
    /// 17 pt regular — la transcripción citada en la revisión.
    case quote
    /// 16 pt semibold — título de push, nombre de una lista, botón grande.
    case pushTitle
    /// 15.5 pt medium — el título de una fila.
    case rowTitle
    /// 15 pt semibold — "Editar", "Nuevo", botones de acción.
    case action
    /// 15 pt regular — la etiqueta de una fila de acceso.
    case label
    /// 14.5 pt medium — "Por revisar", "Compras con Apple Pay".
    case bodyEmphasis
    /// 14.5 pt regular — cuerpo explicativo.
    case explanation
    /// 14 pt regular — el ritmo, notas de apoyo.
    case callout
    /// 13.5 pt regular — valores secundarios, subtítulos con más peso.
    case detail
    /// 13 pt semibold MAYÚSCULAS — encabezado de sección.
    case sectionHeader
    /// 13 pt regular — "día 15 de 30", "Ver el mes".
    case footnote
    /// 12.5 pt regular — el subtítulo de una fila, notas legales.
    case rowSubtitle
    /// 12 pt bold MAYÚSCULAS — encabezado menor.
    case minorHeader
    /// 12 pt regular — texto mínimo de apoyo.
    case caption2
    /// 11 pt — la inicial de un mes bajo una barra.
    case axisLabel
    /// 10.5 pt medium — la etiqueta de una pestaña.
    case tabLabel

    // MARK: Transición

    /// Estilos anteriores al rediseño, ligados a `Font.TextStyle`. Se borran
    /// cuando la última vista migre.
    case largeAmount
    case title
    case headline
    case body
    case caption

    struct Spec {
        let size: CGFloat
        let weight: Font.Weight
        let tracking: CGFloat
        let relativeTo: Font.TextStyle
        let isNumeric: Bool
        let isUppercase: Bool
        let capsDynamicType: Bool
        /// Interlineado como múltiplo del tamaño (1.5 = "interlineado 1.5").
        let lineHeight: CGFloat

        init(
            _ size: CGFloat,
            _ weight: Font.Weight,
            tracking: CGFloat = 0,
            lineHeight: CGFloat = 1,
            numeric: Bool = false,
            uppercase: Bool = false,
            capped: Bool = false) {
            self.size = size
            self.weight = weight
            self.tracking = tracking
            self.lineHeight = lineHeight
            relativeTo = Self.textStyle(for: size)
            isNumeric = numeric
            isUppercase = uppercase
            capsDynamicType = capped
        }

        /// El estilo del sistema cuyo tamaño por defecto queda más cerca, para
        /// que la curva de crecimiento sea la que iOS usa para ese rango.
        private static func textStyle(for size: CGFloat) -> Font.TextStyle {
            switch size {
            case 30...: .largeTitle
            case 24...: .title
            case 21...: .title2
            case 19...: .title3
            case 17...: .headline
            case 15.5...: .callout
            case 14.5...: .subheadline
            case 12.5...: .footnote
            case 11.5...: .caption
            default: .caption2
            }
        }
    }

    var spec: Spec {
        switch self {
        case .heroAmount: Spec(56, .semibold, tracking: -2.2, numeric: true, capped: true)
        case .heroFraction: Spec(26, .semibold, numeric: true, capped: true)
        case .screenAmount: Spec(44, .semibold, tracking: -1.8, numeric: true, capped: true)
        case .totalAmount: Spec(42, .semibold, tracking: -1.6, numeric: true, capped: true)
        case .blockAmount: Spec(28, .semibold, tracking: -1.0, numeric: true)
        case .draftAmount: Spec(24, .semibold, tracking: -0.6, numeric: true)
        case .cardAmount: Spec(22, .semibold, tracking: -0.5, numeric: true)
        case .statAmount: Spec(19, .semibold, numeric: true)
        case .rowAmountStrong: Spec(16.5, .semibold, numeric: true)
        case .rowAmount: Spec(16, .medium, numeric: true)
        case .guideTitle: Spec(31, .semibold, tracking: -1.1, lineHeight: 1.2)
        case .transcript: Spec(26, .medium, tracking: -0.5, lineHeight: 1.4)
        case .screenTitle: Spec(19, .semibold)
        case .summary: Spec(19, .regular, tracking: -0.2, lineHeight: 1.5)
        case .sheetTitle: Spec(17, .semibold)
        case .quote: Spec(17, .regular, lineHeight: 1.5)
        case .pushTitle: Spec(16, .semibold)
        case .rowTitle: Spec(15.5, .medium)
        case .action: Spec(15, .semibold)
        case .label: Spec(15, .regular)
        case .bodyEmphasis: Spec(14.5, .medium)
        case .explanation: Spec(14.5, .regular, lineHeight: 1.55)
        case .callout: Spec(14, .regular, lineHeight: 1.45)
        case .detail: Spec(13.5, .regular, lineHeight: 1.55)
        case .sectionHeader: Spec(13, .semibold, tracking: 0.2, uppercase: true)
        case .footnote: Spec(13, .regular)
        case .rowSubtitle: Spec(12.5, .regular, lineHeight: 1.5)
        case .minorHeader: Spec(12, .bold, tracking: 0.5, uppercase: true)
        case .caption2: Spec(12, .regular)
        case .axisLabel: Spec(11, .regular)
        case .tabLabel: Spec(10.5, .medium)
        case .largeAmount: Spec(34, .bold, numeric: true)
        case .title: Spec(22, .semibold)
        case .headline: Spec(17, .semibold)
        case .body: Spec(17, .regular)
        case .caption: Spec(12, .regular)
        }
    }

    /// El `Font` sin escalar. Para vistas usa `lanaFont(_:)`, que sí escala
    /// con Dynamic Type; esto queda para contextos sin entorno (widgets).
    public var font: Font {
        .system(size: spec.size, weight: spec.weight)
    }
}

/// Aplica tamaño escalado, peso, interletraje, mayúsculas y dígitos
/// tabulares de un `LanaTextStyle`.
struct LanaFontModifier: ViewModifier {
    private let spec: LanaTextStyle.Spec
    @ScaledMetric private var size: CGFloat

    init(style: LanaTextStyle) {
        spec = style.spec
        _size = ScaledMetric(wrappedValue: style.spec.size, relativeTo: style.spec.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: spec.weight))
            .tracking(spec.tracking)
            .lineSpacing(size * (spec.lineHeight - 1))
            .monospacedDigit(spec.isNumeric)
            .textCase(spec.isUppercase ? .uppercase : nil)
    }
}

private extension View {
    @ViewBuilder
    func monospacedDigit(_ isEnabled: Bool) -> some View {
        if isEnabled {
            monospacedDigit()
        } else {
            self
        }
    }
}

public extension View {
    /// Aplica el estilo tipográfico de Lana. Las cifras grandes dejan de
    /// crecer en XXL para no romper el layout; todo lo demás escala libre.
    func lanaFont(_ style: LanaTextStyle) -> some View {
        modifier(LanaFontModifier(style: style))
            .dynamicTypeSize(style.spec.capsDynamicType ? ...DynamicTypeSize.xxLarge : ...DynamicTypeSize
                .accessibility5)
    }
}

import SwiftUI

/// Navegación entre meses: ‹ Septiembre 2026 ›.
///
/// Recibe la etiqueta **ya formateada**, no la fecha: el formato de fechas en
/// español vive en `LanaDateFormat`, que está en `LanaCore` porque los montos y
/// las herramientas de análisis también lo necesitan (ADR-0047). Pedirle la
/// fecha aquí obligaría a que el sistema de diseño dependiera del dominio, y el
/// propio contrato de este componente ya decía que solo recibe primitivos.
public struct MonthSelector: View {
    @Environment(\.lana) private var lana

    private let label: String
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    /// - Parameter label: el mes ya escrito, "Septiembre 2026".
    public init(label: String, onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
        self.label = label
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    public var body: some View {
        PeriodSelector(
            label: label,
            previousLabel: "Mes anterior",
            nextLabel: "Mes siguiente",
            onPrevious: onPrevious,
            onNext: onNext)
    }
}

/// Navegación entre años: ‹ 2026 ›. Misma forma que `MonthSelector`.
public struct YearSelector: View {
    private let year: Int
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    public init(year: Int, onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
        self.year = year
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    public var body: some View {
        PeriodSelector(
            // Sin separador de miles: es un año, no un monto.
            label: String(year),
            previousLabel: "Año anterior",
            nextLabel: "Año siguiente",
            onPrevious: onPrevious,
            onNext: onNext)
    }
}

/// Navegación entre ciclos de corte: ‹ Corte del 12 de octubre ›.
///
/// Misma forma que `MonthSelector`, con una diferencia que el dominio impone:
/// los extremos existen —no hay corte después del vigente, ni antes del primer
/// cargo registrado— y por eso las flechas se pueden apagar.
///
/// Recibe la etiqueta **ya formateada**, igual que `MonthSelector` y por la
/// misma razón (ADR-0047): el formato de fechas en español vive en
/// `LanaDateFormat`, dentro de `LanaCore`, y el sistema de diseño no depende del
/// dominio.
public struct CycleSelector: View {
    private let label: String
    private let canGoPrevious: Bool
    private let canGoNext: Bool
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    /// - Parameters:
    ///   - label: el corte ya escrito, "Corte del 12 de octubre".
    ///   - canGoPrevious: `false` apaga la flecha izquierda sin quitarla.
    ///   - canGoNext: `false` apaga la derecha — el caso del corte vigente.
    public init(
        label: String,
        canGoPrevious: Bool = true,
        canGoNext: Bool = true,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void) {
        self.label = label
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    public var body: some View {
        PeriodSelector(
            label: label,
            previousLabel: "Corte anterior",
            nextLabel: "Corte siguiente",
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: onPrevious,
            onNext: onNext)
    }
}

/// ‹ periodo ›: flechas apagadas con área de toque de 44 pt, el periodo al
/// centro en 17 pt semibold.
private struct PeriodSelector: View {
    @Environment(\.lana) private var lana

    let label: String
    let previousLabel: String
    let nextLabel: String
    /// Los selectores de mes y de año no tienen extremos: se mueven para siempre
    /// en las dos direcciones, así que el default deja las dos flechas vivas.
    var canGoPrevious = true
    var canGoNext = true
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            arrow("chevron.left", label: previousLabel, isEnabled: canGoPrevious, action: onPrevious)
            Spacer()
            Text(label)
                .lanaFont(.sheetTitle)
                .monospacedDigit()
                .foregroundStyle(lana.ink)
                .contentTransition(.numericText())
                // "Corte del 12 de octubre" es más largo que "Septiembre 2026":
                // entre dos áreas de toque de 44 pt y con Dynamic Type grande,
                // se trunca si no se le deja encogerse.
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
            arrow("chevron.right", label: nextLabel, isEnabled: canGoNext, action: onNext)
        }
    }

    /// Una flecha sin a dónde ir deja de dibujarse, pero conserva su área de
    /// 44 pt: así el periodo del centro no brinca al llegar al extremo.
    ///
    /// Se esconde en vez de solo apagarse de color porque el chevron vivo ya usa
    /// `ink35` —el token de texto deshabilitado— y bajarlo un paso más sería una
    /// diferencia que nadie ve. El color nunca es el único portador de
    /// información (Docs/CONVENTIONS.md).
    private func arrow(
        _ systemImage: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .lanaFont(.cardAmount)
                .fontWeight(.regular)
                .foregroundStyle(lana.ink35)
                .opacity(isEnabled ? 1 : 0)
                .frame(width: LanaMetrics.minTouchTarget, height: LanaMetrics.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityHidden(!isEnabled)
    }
}

#Preview {
    VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            VStack {
                MonthSelector(label: "Septiembre 2026", onPrevious: {}, onNext: {})
                YearSelector(year: 2026, onPrevious: {}, onNext: {})
                CycleSelector(
                    label: "Corte del 12 de octubre",
                    canGoNext: false,
                    onPrevious: {},
                    onNext: {})
            }
            .lanaTheme(theme)
        }
    }
    .padding(LanaMetrics.screenMargin)
}

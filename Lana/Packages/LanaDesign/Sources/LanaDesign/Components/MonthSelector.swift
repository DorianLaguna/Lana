import SwiftUI

/// Navegación entre meses: ‹ Septiembre 2026 ›, siempre en español.
///
/// Vive en `LanaDesign` porque lo usan Mes y el Análisis, y las features no se
/// importan entre sí. Solo recibe primitivos.
public struct MonthSelector: View {
    @Environment(\.lana) private var lana

    private let month: Date
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    public init(month: Date, onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
        self.month = month
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    public var body: some View {
        PeriodSelector(
            label: LanaDateFormat.monthYear(month),
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

/// ‹ periodo ›: flechas apagadas con área de toque de 44 pt, el periodo al
/// centro en 17 pt semibold.
private struct PeriodSelector: View {
    @Environment(\.lana) private var lana

    let label: String
    let previousLabel: String
    let nextLabel: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            arrow("chevron.left", label: previousLabel, action: onPrevious)
            Spacer()
            Text(label)
                .lanaFont(.sheetTitle)
                .monospacedDigit()
                .foregroundStyle(lana.ink)
                .contentTransition(.numericText())
            Spacer()
            arrow("chevron.right", label: nextLabel, action: onNext)
        }
    }

    private func arrow(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .lanaFont(.cardAmount)
                .fontWeight(.regular)
                .foregroundStyle(lana.ink35)
                .frame(width: LanaMetrics.minTouchTarget, height: LanaMetrics.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            VStack {
                MonthSelector(month: Date(), onPrevious: {}, onNext: {})
                YearSelector(year: 2026, onPrevious: {}, onNext: {})
            }
            .lanaTheme(theme)
        }
    }
    .padding(LanaMetrics.screenMargin)
}

import SwiftUI

/// Navegación entre años: ‹ 2026 ›. Calca `MonthSelector` — misma forma, mismo
/// par de colores del tema, mismos primitivos.
public struct YearSelector: View {
    @Environment(\.lana) private var lana

    private let year: Int
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    public init(year: Int, onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
        self.year = year
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    public var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Año anterior")
            Spacer()
            // Sin separador de miles: es un año, no un monto.
            Text(String(year))
                .lanaFont(.headline)
                .monospacedDigit()
                .foregroundStyle(lana.textPrimary)
            Spacer()
            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Año siguiente")
        }
        .foregroundStyle(lana.highlight)
    }
}

#Preview {
    VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            LanaCard {
                YearSelector(year: 2026, onPrevious: {}, onNext: {})
            }
            .lanaTheme(theme)
        }
    }
    .padding(Space.md.rawValue)
}

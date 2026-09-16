import LanaDesign
import SwiftUI

/// Lo que se ve entre terminar de dictar y ver los borradores, mientras
/// `parser.parse(_:)` corre. Las frases narran el trabajo que sí está pasando
/// (leer el monto, elegir categoría) sin estar atadas a un callback real.
public struct ParsingIndicatorView: View {
    @Environment(\.lana) private var lana
    @State private var phraseIndex = 0

    private static let phrases = [
        "Leyendo lo que dijiste…",
        "Buscando el monto…",
        "Eligiendo la categoría…",
        "Casi listo…"
    ]

    private static var phraseInterval: Duration {
        .seconds(1.1)
    }

    public init() {}

    public var body: some View {
        VStack(spacing: Space.p14.rawValue) {
            Image(systemName: "sparkles")
                .font(.system(size: LanaMetrics.emptyStateIcon))
                .foregroundStyle(lana.accent)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                .accessibilityHidden(true)

            Text(Self.phrases[phraseIndex])
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink50)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: phraseIndex)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.p40.rawValue)
        // Arranca siempre en la primera frase: iría raro que "Casi listo"
        // apareciera primero.
        .task {
            phraseIndex = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.phraseInterval)
                guard !Task.isCancelled else { return }
                phraseIndex = (phraseIndex + 1) % Self.phrases.count
            }
        }
    }
}

#Preview {
    VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            ParsingIndicatorView()
                .background(LanaColors(theme: theme, colorScheme: .dark).surface)
                .lanaTheme(theme)
        }
    }
}

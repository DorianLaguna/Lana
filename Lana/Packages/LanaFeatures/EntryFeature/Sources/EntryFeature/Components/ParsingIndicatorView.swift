import LanaDesign
import SwiftUI

/// El estado "la IA está pensando" mientras `parser.parse(_:)` corre. Hoy es
/// una sola llamada sin fases reales (Docs/.claude/skills/foundation-models:
/// sesión nueva por parseo, sin `streamResponse` todavía) — las frases de
/// abajo narran el trabajo que sí está pasando (leer el monto, elegir
/// categoría) sin estar atadas a un callback real del parser. Reemplaza el
/// `ProgressView()` desnudo que ocupaba este mismo lugar antes.
public struct ParsingIndicatorView: View {
    @Environment(\.lana) private var lana
    @State private var phraseIndex = 0

    private static let phrases = [
        "Analizando lo que dijiste…",
        "Buscando el monto…",
        "Eligiendo la categoría…",
        "Casi listo…"
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: Space.md.rawValue) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(
                    LinearGradient(
                        colors: [lana.accent, lana.highlight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    in: Circle())
                // El halo inteligente en estado `.processing`: se contrae y
                // gira sobre sí mismo, el gesto de "está pensando" —
                // continuidad visual con el mismo halo del dashboard y de la
                // escucha. El `variableColor` del símbolo se queda: aquí sí
                // aporta (el ícono cambia de tono, no parpadea).
                .background(IntelligenceHalo(state: .processing, baseSize: 68))
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)

            Text(Self.phrases[phraseIndex])
                .lanaFont(.caption)
                .foregroundStyle(lana.ink50)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: phraseIndex)
        }
        // Arranca siempre en la frase 0 cada vez que este stage se muestra
        // — a diferencia de `suggestionText` (que rota contra el reloj de
        // pared y puede empezar a medias), aquí el orden sí importa: iría
        // raro que "Casi listo" apareciera primero.
        .task {
            phraseIndex = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled else { return }
                phraseIndex = (phraseIndex + 1) % Self.phrases.count
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    ParsingIndicatorView()
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

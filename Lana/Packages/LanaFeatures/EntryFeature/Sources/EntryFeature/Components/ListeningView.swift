import LanaDesign
import SwiftUI

/// El micrófono escuchando, con el transcript en vivo (`Escuchando.dc.html`
/// del mockup aprobado). Parada manual — el botón que empieza a escuchar es
/// el mismo que termina (ADR-0015).
public struct ListeningView: View {
    @Environment(\.lana) private var lana

    private let transcript: String
    private let onStop: () -> Void
    private let onClear: () -> Void

    public init(transcript: String, onStop: @escaping () -> Void, onClear: @escaping () -> Void) {
        self.transcript = transcript
        self.onStop = onStop
        self.onClear = onClear
    }

    public var body: some View {
        VStack(spacing: Space.lg.rawValue) {
            Text("Escuchando")
                .lanaFont(.caption)
                .foregroundStyle(lana.warning)
                .textCase(.uppercase)

            Button(action: onStop) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(
                        LinearGradient(
                            colors: [lana.accent, lana.highlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        in: Circle())
                    .symbolEffect(.pulse, options: .repeating)
            }
            .buttonStyle(.plain)

            Text(transcript.isEmpty ? "…" : transcript)
                .lanaFont(.title)
                .foregroundStyle(lana.textPrimary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 60)

            // Detiene y reinicia la misma sesión de escucha (no hay forma
            // confiable de resetear a medias una en curso) — pedido
            // explícito del usuario para no tener que cerrar todo si se
            // equivocó a la mitad de dictar.
            if !transcript.isEmpty {
                Button("Borrar y seguir escuchando", action: onClear)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.highlight)
            }

            Text("Toca el micrófono para terminar")
                .lanaFont(.caption)
                .foregroundStyle(lana.textSecondary)
        }
        .padding(Space.lg.rawValue)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    ListeningView(transcript: "gasté 300 en el súper", onStop: {}, onClear: {})
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

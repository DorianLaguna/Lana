import LanaCore
import LanaDesign
import SwiftUI

/// El micrófono escuchando, con el transcript en vivo (`Escuchando.dc.html`
/// del mockup aprobado). Parada manual — el botón que empieza a escuchar es
/// el mismo que termina (ADR-0015).
public struct ListeningView: View {
    @Environment(\.lana) private var lana

    private let transcript: String
    private let preview: [DraftTransaction]
    private let onStop: () -> Void
    private let onClear: () -> Void

    /// - Parameter preview: lo que el parser ya entendió mientras se sigue
    ///   dictando (ADR-0043) — vacío hasta la primera pausa.
    public init(
        transcript: String,
        preview: [DraftTransaction] = [],
        onStop: @escaping () -> Void,
        onClear: @escaping () -> Void) {
        self.transcript = transcript
        self.preview = preview
        self.onStop = onStop
        self.onClear = onClear
    }

    public var body: some View {
        VStack(spacing: Space.lg.rawValue) {
            Text("Escuchando")
                .lanaFont(.caption)
                .foregroundStyle(lana.attention)
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
                    // El mismo halo inteligente del dashboard, ahora en
                    // estado `.listening`: se abre y respira con más vida
                    // que en reposo, acompañando al waveform de abajo. El
                    // mic se queda sólido; nada de `.symbolEffect(.pulse)`,
                    // que lo hacía parpadear como "apagándose".
                    .background(IntelligenceHalo(state: .listening))
            }
            .buttonStyle(.plain)

            // Las ondas de voz en movimiento: la señal de "te estoy
            // escuchando" que un mic estático no da. Van justo bajo el
            // micrófono, como el sonido saliendo de él hacia el transcript.
            VoiceWaveformView()

            transcriptView

            if !preview.isEmpty {
                previewView
                    .transition(.opacity)
            }

            // Detiene y reinicia la misma sesión de escucha (no hay forma
            // confiable de resetear a medias una en curso) — pedido
            // explícito del usuario para no tener que cerrar todo si se
            // equivocó a la mitad de dictar.
            if !transcript.isEmpty {
                Button("Borrar y seguir escuchando", action: onClear)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.accent)
            }

            Text("Toca el micrófono para terminar")
                .lanaFont(.caption)
                .foregroundStyle(lana.ink50)
        }
        .padding(Space.lg.rawValue)
        .animation(.easeInOut(duration: 0.25), value: preview)
    }

    /// Lo que se va entendiendo, sin esperar a que se toque el micrófono:
    /// si el monto o el concepto salen mal, se nota mientras todavía se
    /// puede decir otra vez. Solo lectura — editar es en la revisión.
    private var previewView: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                Text("Lo que llevo")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.ink50)
                ForEach(preview) { draft in
                    HStack(spacing: Space.sm.rawValue) {
                        Text(Self.title(for: draft))
                            .lanaFont(.body)
                            .foregroundStyle(lana.ink)
                            .lineLimit(1)
                        Spacer(minLength: Space.sm.rawValue)
                        Text(Self.amount(for: draft))
                            .lanaFont(.body)
                            .monospacedDigit()
                            .foregroundStyle(draft.kind == .income ? lana.positive : lana.ink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func title(for draft: DraftTransaction) -> String {
        if !draft.concept.isEmpty {
            return draft.concept
        }
        if !draft.category.isEmpty {
            return draft.category
        }
        return "Sin concepto"
    }

    /// Un ingreso lleva su signo además del color — el color nunca es el
    /// único portador de información (skill de theming).
    private static func amount(for draft: DraftTransaction) -> String {
        let formatted = Money(amount: draft.amount, currency: draft.currency).formatted()
        return draft.kind == .income ? "+\(formatted)" : formatted
    }

    /// El transcript crece con lo que se va diciendo, hasta donde dé la
    /// hoja, y de ahí se desplaza. Antes era un `Text` suelto: al no caber
    /// en el alto fijo de la hoja, SwiftUI lo cortaba en dos renglones y
    /// puntos suspensivos, así que a media frase larga ya no había forma de
    /// saber si lo que se dictó era lo correcto — que es justo para lo que
    /// existe esta pantalla. `bottomID` ancla el final: cada palabra nueva
    /// desplaza al último renglón, para que lo que se ve sea siempre lo que
    /// se acaba de decir y no el principio de la frase.
    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Text(transcript.isEmpty ? "…" : transcript)
                        .lanaFont(.title)
                        .foregroundStyle(lana.ink)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomID)
                }
            }
            .frame(minHeight: 60, maxHeight: .infinity)
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: transcript) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.bottomID, anchor: .bottom)
                }
            }
        }
    }

    private static let bottomID = "transcript-bottom"
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    ListeningView(
                        transcript: "gasté 300 en el súper y cobré la quincena",
                        preview: [
                            DraftTransaction(amount: 300, concept: "súper", category: "despensa"),
                            DraftTransaction(kind: .income, amount: 12000, concept: "quincena")
                        ],
                        onStop: {},
                        onClear: {})
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

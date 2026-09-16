import LanaCore
import LanaDesign
import SwiftUI

/// "Escuchando" (rediseño, sección 07). Empieza a escuchar de inmediato y la
/// persona decide cuándo termina: no hay corte por silencio (ADR-0015).
public struct ListeningView: View {
    @Environment(\.lana) private var lana
    @State private var showsSuggestions = false

    private let transcript: String
    private let finalizedTranscript: String
    private let level: Float
    private let preview: [DraftTransaction]
    private let onStop: () -> Void
    private let onClear: () -> Void

    private static let suggestions = [
        "300 de súper y 120 en uber",
        "pagué 250 de gasolina con la Nu",
        "me llegó el sueldo"
    ]

    /// Cuánto silencio espera antes de sugerir qué decir.
    private static var suggestionDelay: Duration {
        .seconds(3)
    }

    /// Cada cuánto rota la sugerencia.
    private static var suggestionInterval: TimeInterval {
        4
    }

    /// - Parameters:
    ///   - transcript: todo lo oído hasta ahora.
    ///   - finalizedTranscript: el prefijo que ya no va a cambiar; lo demás es
    ///     la palabra en curso y se dibuja apagada.
    ///   - level: el volumen del micrófono, de 0 a 1.
    ///   - preview: lo que el parser ya entendió mientras se sigue dictando
    ///     (ADR-0043) — vacío hasta la primera pausa.
    public init(
        transcript: String,
        finalizedTranscript: String = "",
        level: Float = 0,
        preview: [DraftTransaction] = [],
        onStop: @escaping () -> Void,
        onClear: @escaping () -> Void) {
        self.transcript = transcript
        self.finalizedTranscript = finalizedTranscript
        self.level = level
        self.preview = preview
        self.onStop = onStop
        self.onClear = onClear
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text("Escuchando")
                .lanaFont(.minorHeader)
                .foregroundStyle(lana.attention)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Space.p38.rawValue)

            transcriptView
                .padding(.bottom, Space.p26.rawValue)

            VoiceWaveformView(level: level)
                .padding(.bottom, Space.md.rawValue)

            suggestionArea
                .padding(.bottom, Space.p28.rawValue)

            if !preview.isEmpty {
                previewView
                    .padding(.bottom, Space.lg.rawValue)
                    .transition(.opacity)
            }

            stopButton
                .padding(.bottom, Space.p18.rawValue)

            if !transcript.isEmpty {
                Button("Borrar y seguir escuchando", action: onClear)
                    .buttonStyle(.lana(.secondary, size: .medium))
                    .padding(.bottom, Space.p18.rawValue)
                    .transition(.opacity)
            }

            Text("Toca para terminar · todo en tu teléfono")
                .lanaFont(.detail)
                .foregroundStyle(lana.ink42)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Space.p28.rawValue)
        .padding(.vertical, Space.p40.rawValue)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: preview)
        .animation(.easeInOut(duration: 0.25), value: transcript.isEmpty)
        .task(id: transcript.isEmpty) {
            showsSuggestions = false
            guard transcript.isEmpty else { return }
            try? await Task.sleep(for: Self.suggestionDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { showsSuggestions = true }
        }
    }

    // MARK: - Transcripción

    /// Hasta cuatro renglones; al pasarse hace scroll anclado al final, para
    /// que lo visible sea siempre lo que se acaba de decir.
    private var transcriptView: some View {
        ScrollView {
            styledTranscript
                .lanaFont(.transcript)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.bottom)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: LanaMetrics.transcriptMaxHeight)
        .fixedSize(horizontal: false, vertical: true)
        // VoiceOver lee frases completas, no palabra por palabra.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(finalizedTranscript.isEmpty ? "Escuchando" : finalizedTranscript)
    }

    private var styledTranscript: Text {
        guard !transcript.isEmpty else {
            return Text("…").foregroundStyle(lana.ink30)
        }
        let finalized = transcript.hasPrefix(finalizedTranscript) ? finalizedTranscript : ""
        let partial = String(transcript.dropFirst(finalized.count))
        let settled = Text(finalized).foregroundStyle(lana.ink)
        guard !partial.trimmingCharacters(in: .whitespaces).isEmpty else { return settled }
        let pending = Text("\(partial)…").foregroundStyle(lana.ink30)
        return Text("\(settled)\(pending)")
    }

    // MARK: - Sugerencias

    @ViewBuilder
    private var suggestionArea: some View {
        if transcript.isEmpty, showsSuggestions {
            TimelineView(.periodic(from: .now, by: Self.suggestionInterval)) { context in
                let index = Int(context.date.timeIntervalSinceReferenceDate / Self.suggestionInterval)
                    % Self.suggestions.count
                Text("Prueba a decir: \(Self.suggestions[index])")
                    .lanaFont(.explanation)
                    .foregroundStyle(lana.ink42)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: index)
            }
            .transition(.opacity)
        }
    }

    // MARK: - Lo que llevo

    /// Lo que se va entendiendo antes de terminar (ADR-0043): si el monto sale
    /// mal, se nota mientras todavía se puede decir otra vez. Solo lectura.
    private var previewView: some View {
        VStack(spacing: Space.sm.rawValue) {
            ForEach(preview) { draft in
                HStack(spacing: Space.sm.rawValue) {
                    Text(Self.title(for: draft))
                        .lanaFont(.bodyEmphasis)
                        .foregroundStyle(lana.ink70)
                        .lineLimit(1)
                    Spacer(minLength: Space.sm.rawValue)
                    Text(Self.amount(for: draft))
                        .lanaFont(.rowAmount)
                        .foregroundStyle(draft.kind == .income ? lana.positive : lana.ink)
                }
            }
        }
        .padding(.vertical, Space.p12.rawValue)
        .padding(.horizontal, Space.md.rawValue)
        .background(lana.bg, in: RoundedRectangle(cornerRadius: Radius.inner.rawValue, style: .continuous))
    }

    private static func title(for draft: DraftTransaction) -> String {
        if !draft.concept.isEmpty {
            return draft.concept
        }
        return draft.category.isEmpty ? "Sin concepto" : draft.category
    }

    /// Un ingreso lleva su signo además del color.
    private static func amount(for draft: DraftTransaction) -> String {
        let formatted = Money(amount: draft.amount, currency: draft.currency).formatted()
        return draft.kind == .income ? "+\(formatted)" : formatted
    }

    // MARK: - Terminar

    private var stopButton: some View {
        Button(action: onStop) {
            RoundedRectangle(cornerRadius: Radius.swatch.rawValue, style: .continuous)
                .fill(lana.bg)
                .frame(width: LanaMetrics.stopGlyph, height: LanaMetrics.stopGlyph)
                .frame(width: LanaMetrics.stopButton, height: LanaMetrics.stopButton)
                .background(lana.ink, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Terminar de dictar")
        .accessibilityHint("Toca para terminar")
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                ListeningView(
                    transcript: "300 de súper y 120 en ub",
                    finalizedTranscript: "300 de súper",
                    level: 0.6,
                    preview: [DraftTransaction(amount: 300, concept: "súper", category: "despensa")],
                    onStop: {},
                    onClear: {})
                    .background(LanaColors(theme: theme, colorScheme: .dark).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

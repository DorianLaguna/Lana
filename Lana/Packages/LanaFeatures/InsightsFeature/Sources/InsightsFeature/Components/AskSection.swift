import LanaDesign
import SwiftUI

/// "Pregúntale a Lana" (rediseño, sección 10): el campo, las preguntas
/// sugeridas como chips y la respuesta.
///
/// Los atajos van en chips y no en filas con chevron: una fila con chevron
/// promete navegación, y esto no navega a ningún lado — contesta ahí mismo.
///
/// Las sugeridas son fijas, no generadas: cada una corresponde a un cálculo
/// determinista que sí existe. Sugerir algo que después no se puede contestar
/// sería peor que no sugerir nada.
struct AskSection: View {
    @Environment(\.lana) private var lana

    let question: Binding<String>
    let suggestions: [String]
    let answer: String?
    let isAnswering: Bool
    let onAsk: () -> Void
    let onAskSuggestion: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.p14.rawValue) {
            SectionHeader("Pregúntale a Lana", style: .minor)

            field

            if isAnswering {
                HStack(spacing: Space.sm.rawValue) {
                    ProgressView()
                    Text("Consultando tus números…")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                }
            } else if let answer, !answer.isEmpty {
                answerCard(answer)
            }

            // Las sugeridas se quedan aunque ya haya respuesta: si las
            // sustituyeran, después de preguntar una vez no habría forma de ver
            // las demás sin borrar lo escrito.
            if !suggestions.isEmpty, !isAnswering {
                FlowLayout {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Chip(suggestion, tone: .suggestion) { onAskSuggestion(suggestion) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var field: some View {
        HStack(spacing: Space.p10.rawValue) {
            TextField("Escribe tu pregunta…", text: question)
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink)
                .submitLabel(.send)
                .onSubmit(onAsk)

            Button(action: onAsk) {
                Image(systemName: "arrow.up")
                    .lanaFont(.rowSubtitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(canAsk ? lana.ink : lana.ink35)
                    .frame(width: LanaMetrics.sendButton, height: LanaMetrics.sendButton)
                    .background(lana.surface3, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canAsk)
            .accessibilityLabel("Preguntar")
        }
        .padding(.vertical, Space.p13.rawValue)
        .padding(.horizontal, Space.md.rawValue)
        .background(lana.bg, in: Capsule())
    }

    /// La respuesta se puede borrar: es de una sola pregunta, no un historial.
    private func answerCard(_ answer: String) -> some View {
        LanaCard(padding: .p14, radius: .inner, fill: .background) {
            VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
                    Text(question.wrappedValue)
                        .lanaFont(.footnote)
                        .foregroundStyle(lana.ink42)
                    Spacer(minLength: Space.sm.rawValue)
                    Button {
                        onClear()
                    } label: {
                        Image(systemName: "xmark")
                            .lanaFont(.caption2)
                            .foregroundStyle(lana.ink35)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Borrar la pregunta y su respuesta")
                }
                Text(answer)
                    .lanaFont(.rowTitle)
                    .fontWeight(.regular)
                    .foregroundStyle(lana.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var canAsk: Bool {
        !question.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnswering
    }
}

#Preview {
    @Previewable @State var question = ""

    return VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            AskSection(
                question: $question,
                suggestions: ["¿Cuánto me queda de esta quincena?", "¿Cuánto debo en mis tarjetas?"],
                answer: nil,
                isAnswering: false,
                onAsk: {},
                onAskSuggestion: { _ in },
                onClear: {})
                .padding(LanaMetrics.screenMargin)
                .background(LanaColors(theme: theme, colorScheme: .dark).surface)
                .lanaTheme(theme)
        }
    }
}

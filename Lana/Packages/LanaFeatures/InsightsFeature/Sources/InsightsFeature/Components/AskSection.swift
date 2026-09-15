import LanaDesign
import SwiftUI

/// Preguntar en lenguaje natural sobre los propios datos
/// (Docs/PLAN.md → Fase 9).
///
/// Las preguntas sugeridas son fijas, no generadas: cada una corresponde a un
/// cálculo determinista que sí existe. Sugerir algo que después no se puede
/// contestar sería peor que no sugerir nada.
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
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                HStack {
                    SectionCaption("Pregúntale a Lana")
                    Spacer()
                    // Solo cuando hay algo que borrar: un botón que no hace
                    // nada es ruido.
                    if hasSomethingToClear {
                        Button("Borrar", action: onClear)
                            .lanaFont(.caption)
                            .foregroundStyle(lana.highlight)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Borrar la pregunta y su respuesta")
                    }
                }

                HStack(spacing: Space.sm.rawValue) {
                    LanaTextField("¿En qué se me fue el dinero?", text: question)
                    Button(action: onAsk) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(canAsk ? lana.accent : lana.separator)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAsk)
                    .accessibilityLabel("Preguntar")
                }

                if isAnswering {
                    HStack(spacing: Space.sm.rawValue) {
                        ProgressView()
                        Text("Consultando tus números…")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    }
                } else if let answer, !answer.isEmpty {
                    Text(answer)
                        .lanaFont(.body)
                        .foregroundStyle(lana.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Las sugeridas se quedan aunque ya haya respuesta: antes la
                // sustituían, y después de preguntar una vez no había forma de
                // ver las demás sin borrar lo escrito a mano.
                if !suggestions.isEmpty, !isAnswering {
                    Divider()
                    if hasAnswer {
                        SectionCaption("Otra pregunta")
                    }
                    suggestionRows
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var hasAnswer: Bool {
        !(answer ?? "").isEmpty
    }

    private var hasSomethingToClear: Bool {
        hasAnswer || !question.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canAsk: Bool {
        !question.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnswering
    }

    /// Las sugeridas como filas tocables, no como frases sueltas.
    ///
    /// Antes eran texto plano apilado: se leían como una lista de ejemplos, no
    /// como algo que se pudiera tocar. Ahora usan el chevron estándar de la app
    /// y una línea entre filas, igual que cualquier otra fila navegable.
    private var suggestionRows: some View {
        VStack(spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onAskSuggestion(suggestion)
                } label: {
                    HStack(spacing: Space.sm.rawValue) {
                        Text(suggestion)
                            .lanaFont(.body)
                            .foregroundStyle(lana.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(lana.textSecondary.opacity(0.6))
                    }
                    // Blanco táctil de 44pt: una frase de un renglón mide
                    // menos (design-reviewer.md).
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if suggestion != suggestions.last {
                    Divider()
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var question = ""

    return VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            AskSection(
                question: $question,
                suggestions: ["¿En qué se me fue el dinero este mes?", "¿Cuánto debo en mis tarjetas?"],
                answer: nil,
                isAnswering: false,
                onAsk: {},
                onAskSuggestion: { _ in },
                onClear: {})
                .lanaTheme(theme)
        }
    }
    .padding(Space.md.rawValue)
}

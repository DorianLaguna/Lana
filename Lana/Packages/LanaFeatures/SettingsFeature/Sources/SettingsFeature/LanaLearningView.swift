import LanaCore
import LanaDesign
import SwiftUI

/// "Aprendizaje de Lana": lo que Lana ha aprendido de las correcciones del
/// usuario (ADR-0012). Antes vivía dentro de `SettingsView`; ahora es su
/// propia pantalla, pero la lógica es la misma — refleja `SettingsModel` y
/// llama a sus métodos, sin estado de negocio propio.
///
/// Conserva todo lo que ya existía: conteo `×N`, categoría con su color del
/// ramp, borrado individual y "Borrar todo". El botón de regresar lo da el
/// `NavigationStack` de `SettingsView`.
struct LanaLearningView: View {
    @Environment(\.lana) private var lana
    private let model: SettingsModel
    @State private var isConfirmingDeleteAll = false
    @State private var termPendingDelete: String?

    init(model: SettingsModel) {
        self.model = model
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md.rawValue) {
                Text("Lana aprende de las correcciones que haces al registrar tus gastos.")
                    .lanaFont(.body)
                    .foregroundStyle(lana.textSecondary)

                if !model.vocabulary.isEmpty {
                    HStack {
                        Text(wordCountText)
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                        Spacer()
                        Button("Borrar todo", role: .destructive) {
                            isConfirmingDeleteAll = true
                        }
                        .lanaFont(.caption)
                    }
                }

                vocabularyList
            }
            .padding(Space.md.rawValue)
            .floatingMicClearance()
        }
        .background(lana.surface)
        .navigationTitle("Aprendizaje de Lana")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .confirmationDialog(
                "¿Borrar todo el vocabulario aprendido?",
                isPresented: $isConfirmingDeleteAll,
                titleVisibility: .visible) {
                    Button("Borrar todo", role: .destructive) {
                        Task { await model.deleteAll() }
                    }
            }
            // Un solo diálogo para toda la lista, no uno montado por renglón
            // dentro del `ForEach`: cuál término se borra ya lo dice
            // `termPendingDelete`.
            .confirmationDialog(
                deleteTermTitle,
                isPresented: Binding(
                    get: { termPendingDelete != nil },
                    set: { isPresented in
                        if !isPresented {
                            termPendingDelete = nil
                        }
                    }),
                titleVisibility: .visible) {
                    if let term = termPendingDelete {
                        Button("Borrar", role: .destructive) {
                            Task { await model.delete(term: term) }
                            termPendingDelete = nil
                        }
                    }
            }
    }

    private var deleteTermTitle: String {
        guard let termPendingDelete else { return "" }
        return "¿Borrar «\(termPendingDelete)»?"
    }

    private var wordCountText: String {
        let count = model.learnedWordCount
        return count == 1 ? "1 palabra aprendida" : "\(count) palabras aprendidas"
    }

    @ViewBuilder
    private var vocabularyList: some View {
        if model.vocabulary.isEmpty {
            EmptyStateView(
                systemImage: "text.book.closed",
                title: "Todavía no hay nada aprendido",
                message: "Aparece aquí en cuanto corrijas la categoría de un gasto.")
        } else {
            LanaCard {
                VStack(spacing: 0) {
                    ForEach(model.vocabulary) { entry in
                        HStack {
                            Text(entry.term)
                                .lanaFont(.body)
                                .foregroundStyle(lana.textPrimary)
                            Spacer()
                            Text("×\(entry.useCount)")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.textSecondary)
                            Text(entry.category.capitalized)
                                .lanaFont(.caption)
                                .foregroundStyle(lana.categoryRamp[entry.category.lowercased().stableRampIndex])
                                .padding(.horizontal, Space.xs.rawValue)
                                .padding(.vertical, 4)
                                .background(
                                    lana.categoryRamp[entry.category.lowercased().stableRampIndex].opacity(0.15),
                                    in: Capsule())
                            Button {
                                termPendingDelete = entry.term
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(lana.critical)
                            }
                            .buttonStyle(.plain)
                            // Sin esto VoiceOver solo anuncia "basurero", sin
                            // decir qué palabra se olvida.
                            .accessibilityLabel("Olvidar «\(entry.term)»")
                        }
                        .padding(.vertical, Space.xs.rawValue)
                        if entry.id != model.vocabulary.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            LanaLearningView(model: SettingsModel(
                vocabularyStore: InMemoryCorrectionVocabularyStore(seed: [
                    CorrectionEntry(term: "bocina", category: "ocio", useCount: 4),
                    CorrectionEntry(term: "chicles", category: "despensa", useCount: 7)
                ]),
                syncStatusReporting: InMemorySyncStatusReporting(.synced(lastSuccess: .now)),
                userDefaults: UserDefaults(suiteName: "preview") ?? .standard))
        }
        .lanaTheme(theme)
    }
}

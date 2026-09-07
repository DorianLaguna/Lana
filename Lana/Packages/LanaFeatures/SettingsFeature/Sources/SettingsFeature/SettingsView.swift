import LanaCore
import LanaDesign
import SwiftUI

/// Ajustes: tema y vocabulario aprendido (Fase 6.5, calca `Ajustes.dc.html`).
/// Sin lógica propia — refleja `SettingsModel`.
public struct SettingsView: View {
    @Environment(\.lana) private var lana
    private let model: SettingsModel
    @State private var isConfirmingDeleteAll = false
    @State private var termPendingDelete: String?

    public init(model: SettingsModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg.rawValue) {
                    syncStatusRow

                    VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                        Text("Tema")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                        themeGrid
                    }

                    if model.showsConfigureApplePayRow {
                        configureApplePayRow
                    }

                    VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                        HStack {
                            Text("Vocabulario aprendido")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.textSecondary)
                            Spacer()
                            if !model.vocabulary.isEmpty {
                                Button("Borrar todo", role: .destructive) {
                                    isConfirmingDeleteAll = true
                                }
                                .lanaFont(.caption)
                            }
                        }
                        vocabularyList
                        Text("""
                        Lana aprende de tus correcciones: cuando cambias la categoría de un \
                        gasto, recuerda esa palabra para la próxima vez.
                        """)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.textSecondary)
                    }
                }
                .padding(Space.md.rawValue)
            }
            .background(lana.surface)
            .navigationTitle("Ajustes")
            .task { await model.onAppear() }
            .confirmationDialog(
                "¿Borrar todo el vocabulario aprendido?",
                isPresented: $isConfirmingDeleteAll,
                titleVisibility: .visible) {
                    Button("Borrar todo", role: .destructive) {
                        Task { await model.deleteAll() }
                    }
            }
        }
    }

    /// Que el usuario sepa que su información sí está respaldada en la nube
    /// — nunca solo "iCloud está activo": si el sync falló en silencio,
    /// decirlo aquí también (ADR-0020). Tono "dato, no alarma" incluso para
    /// `.failed` (Docs/CLAUDE.md → Tono del producto).
    private var syncStatusRow: some View {
        LanaCard {
            HStack(spacing: Space.sm.rawValue) {
                syncStatusIcon
                Text(syncStatusText)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.textSecondary)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var syncStatusIcon: some View {
        switch model.syncStatus {
        case .disabled:
            Image(systemName: "icloud.slash")
                .foregroundStyle(lana.textSecondary)
        case .syncing:
            ProgressView()
                .controlSize(.small)
        case .synced:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(lana.textSecondary)
        case .failed:
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(lana.textSecondary)
        }
    }

    private var syncStatusText: String {
        switch model.syncStatus {
        case .disabled:
            "Sin iCloud activo — tus datos solo viven en este dispositivo"
        case .syncing:
            "Sincronizando…"
        case let .synced(lastSuccess):
            "Sincronizado con iCloud — \(lastSuccess.formatted(.relative(presentation: .named)))"
        case .failed:
            """
            No se pudo respaldar en iCloud la última vez — tus datos siguen aquí, en tu \
            dispositivo. Revisa tu conexión o el espacio disponible en iCloud.
            """
        }
    }

    /// Punto de entrada persistente para reabrir la guía de Apple Pay
    /// después del onboarding (R1.4). Fila etiquetada y seleccionable — el
    /// toque solo delega en el modelo, que dispara el handler inyectado por
    /// `ContentView` (las features no se importan entre sí, así que la guía
    /// vive en otra feature y se presenta desde el target de la app).
    private var configureApplePayRow: some View {
        Button {
            model.configureApplePay()
        } label: {
            LanaCard {
                HStack(spacing: Space.sm.rawValue) {
                    Image(systemName: "creditcard.and.123")
                        .foregroundStyle(lana.accent)
                    Text("Configurar Apple Pay")
                        .lanaFont(.body)
                        .foregroundStyle(lana.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .lanaFont(.caption)
                        .foregroundStyle(lana.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var themeGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Space.sm.rawValue)], spacing: Space.sm.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                ThemeSwatch(theme: theme, isSelected: theme == model.selectedTheme) {
                    model.selectTheme(theme)
                }
            }
        }
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
                            // Reemplaza `.swipeActions`, que no hacía nada aquí
                            // — ese modificador solo funciona dentro de un
                            // `List`, y esta fila vive en un `VStack` normal
                            // dentro de `LanaCard` (se ignoraba en silencio;
                            // nunca hubo forma real de borrar un solo término).
                            Button {
                                termPendingDelete = entry.term
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(lana.critical)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, Space.xs.rawValue)
                        .confirmationDialog(
                            "¿Borrar «\(entry.term)»?",
                            isPresented: Binding(
                                get: { termPendingDelete == entry.term },
                                set: { isPresented in
                                    if !isPresented {
                                        termPendingDelete = nil
                                    }
                                })) {
                            Button("Borrar", role: .destructive) {
                                Task { await model.delete(term: entry.term) }
                                termPendingDelete = nil
                            }
                        }
                        if entry.id != model.vocabulary.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct ThemeSwatch: View {
    @Environment(\.colorScheme) private var colorScheme
    let theme: LanaTheme
    let isSelected: Bool
    let onTap: () -> Void

    private var colors: LanaColors {
        LanaColors(theme: theme, colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Space.xs.rawValue) {
                ZStack {
                    Circle()
                        .fill(colors.accent)
                        .frame(width: 30, height: 30)
                        .offset(x: -7, y: -7)
                    Circle()
                        .fill(colors.highlight)
                        .frame(width: 30, height: 30)
                        .offset(x: 7, y: 7)
                }
                .frame(width: 44, height: 36)

                Text(theme.displayName)
                    .lanaFont(.caption)
                    .foregroundStyle(colors.textPrimary)
            }
            .padding(Space.sm.rawValue)
            .frame(maxWidth: .infinity)
            .background(colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Space.sm.rawValue, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Space.sm.rawValue, style: .continuous)
                        .strokeBorder(colors.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

extension String {
    /// Si es una de las categorías cerradas, su índice ya es único por
    /// construcción (`SuggestedCategory.rampIndex`). Si no, cae a un hash
    /// estable (djb2) — el `Hashable` de Swift cambia de semilla en cada
    /// corrida del proceso y no sirve para esto. El módulo (12) tiene que
    /// coincidir con `LanaColors.categoryRamp.count`. Copia local: la misma
    /// idea vive en `DashboardFeature`/`CardsFeature`, y las features no se
    /// importan entre sí.
    var stableRampIndex: Int {
        if let known = SuggestedCategory(rawValue: self) {
            return known.rampIndex
        }
        var hash = 5381
        for scalar in unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash) % 12
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        SettingsView(model: SettingsModel(
            vocabularyStore: InMemoryCorrectionVocabularyStore(seed: [
                CorrectionEntry(term: "bocina", category: "ocio", useCount: 4),
                CorrectionEntry(term: "chicles", category: "despensa", useCount: 7)
            ]),
            syncStatusReporting: InMemorySyncStatusReporting(.synced(lastSuccess: .now)),
            userDefaults: UserDefaults(suiteName: "preview") ?? .standard))
            .lanaTheme(theme)
    }
}

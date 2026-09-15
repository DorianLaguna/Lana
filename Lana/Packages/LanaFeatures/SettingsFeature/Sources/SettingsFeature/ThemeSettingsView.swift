import LanaCore
import LanaDesign
import SwiftUI

/// "Tema": el selector visual completo de los ocho temas curados (ADR-0006).
/// Antes vivía expandido dentro de `SettingsView` y dominaba la pantalla;
/// ahora tiene la suya, y Ajustes solo muestra una fila con el tema activo.
///
/// El diseño de los swatches no cambió —funciona bien—; solo se movió de
/// lugar. Refleja `SettingsModel`; el toque persiste el tema al instante,
/// sin botón de guardar.
struct ThemeSettingsView: View {
    @Environment(\.lana) private var lana
    private let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md.rawValue) {
                Text("""
                El tema cambia los colores de toda la app. Se aplica al momento de \
                tocarlo — no hay nada que guardar.
                """)
                .lanaFont(.body)
                .foregroundStyle(lana.ink50)
                .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: Space.sm.rawValue)],
                    spacing: Space.sm.rawValue) {
                        ForEach(LanaTheme.allCases) { theme in
                            ThemeSwatch(theme: theme, isSelected: theme == model.selectedTheme) {
                                model.selectTheme(theme)
                            }
                        }
                    }
            }
            .padding(Space.md.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle("Tema")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Un swatch del selector de tema: el par curado (accent + highlight) del
/// tema y su nombre, con borde de acento cuando está elegido. Cada swatch se
/// pinta con SUS propios colores (no los del tema activo) para que el
/// usuario vea el aspecto real de cada opción.
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

                HStack(spacing: Space.xs.rawValue) {
                    // La palomita, no solo el borde de acento: el color nunca
                    // es el único portador de información (daltonismo, escala
                    // de grises — Docs/.claude/skills/theming).
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .lanaFont(.caption)
                            .foregroundStyle(colors.accent)
                    }
                    Text(theme.displayName)
                        .lanaFont(.caption)
                        .foregroundStyle(colors.ink)
                }
            }
            .padding(Space.sm.rawValue)
            .frame(maxWidth: .infinity)
            .background(colors.surface, in: RoundedRectangle(cornerRadius: Space.sm.rawValue, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Space.sm.rawValue, style: .continuous)
                        .strokeBorder(colors.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            ThemeSettingsView(model: SettingsModel(
                vocabularyStore: InMemoryCorrectionVocabularyStore(),
                syncStatusReporting: InMemorySyncStatusReporting(.synced(lastSuccess: .now)),
                userDefaults: UserDefaults(suiteName: "preview") ?? .standard))
        }
        .lanaTheme(theme)
    }
}

import LanaCore
import LanaDesign
import SwiftUI

// Las dos pantallas de texto de la sección "Acerca de". No hay una pantalla
// intermedia que las agrupe: la sección son tres renglones cortos
// (Privacidad, Acerca de Lana, Versión) y `SettingsView` los muestra en su
// tarjeta directamente. Un submenú para eso solo agregaba un toque.
//
// El botón de regresar lo da el `NavigationStack` de `SettingsView`.

/// Texto breve de privacidad, en lenguaje de usuario. Deja claro lo que ya
/// es cierto por arquitectura: el procesamiento es en el dispositivo y los
/// datos viven en el iCloud del propio usuario (ADR-0002, ADR-0020).
struct PrivacyView: View {
    @Environment(\.lana) private var lana

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md.rawValue) {
                Text("Tus datos son tuyos")
                    .lanaFont(.title)
                    .foregroundStyle(lana.textPrimary)
                Text("""
                Lo que registras en Lana se guarda en tu iCloud, en tu cuenta, no en \
                servidores nuestros. Lo que le dictas se procesa en tu dispositivo para \
                convertirlo en un gasto.
                """)
                .lanaFont(.body)
                .foregroundStyle(lana.textSecondary)
            }
            .padding(Space.md.rawValue)
            .floatingMicClearance()
        }
        .background(lana.surface)
        .navigationTitle("Privacidad")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Presentación breve de Lana: qué es, en una pantalla. El "cómo funciona"
/// con el flujo detallado vive en `LanaInfoView`, dentro de la sección LANA.
struct AboutLanaView: View {
    @Environment(\.lana) private var lana

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md.rawValue) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lana.accent, lana.highlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                Text("Lana")
                    .lanaFont(.title)
                    .foregroundStyle(lana.textPrimary)
                Text("""
                Lana es tu asistente financiero: le dices lo que gastaste con tus palabras \
                y ella lo registra, aprende de tus correcciones y te ayuda a llevar tus \
                cuentas al día.
                """)
                .lanaFont(.body)
                .foregroundStyle(lana.textSecondary)
            }
            .padding(Space.md.rawValue)
            .floatingMicClearance()
        }
        .background(lana.surface)
        .navigationTitle("Acerca de Lana")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview("Privacidad") {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            PrivacyView()
        }
        .lanaTheme(theme)
    }
}

#Preview("Acerca de Lana") {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            AboutLanaView()
        }
        .lanaTheme(theme)
    }
}

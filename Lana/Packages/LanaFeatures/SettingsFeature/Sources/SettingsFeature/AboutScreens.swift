import LanaCore
import LanaDesign
import SwiftUI

// Las dos pantallas de texto de "Acerca de". No hay una pantalla intermedia
// que las agrupe: son dos renglones en la tarjeta de Ajustes, y un submenú
// para eso solo agregaba un toque.
//
// Se empujan desde Ajustes, así que no llevan barra de pestañas. El botón de
// regresar lo da el `NavigationStack`.

/// Privacidad, en lenguaje de usuario: dice lo que ya es cierto por
/// arquitectura — el procesamiento es en el dispositivo y los datos viven en
/// el iCloud del propio usuario (ADR-0002, ADR-0020).
struct PrivacyView: View {
    @Environment(\.lana) private var lana

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                Text("Tus datos son tuyos")
                    .lanaFont(.screenTitle)
                    .foregroundStyle(lana.ink)
                Text("""
                Lo que registras en Lana se guarda en tu iCloud, en tu cuenta, no en servidores \
                nuestros. Lo que le dictas se procesa en tu iPhone para convertirlo en un movimiento.
                """)
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)

                // Las cifras del análisis las calcula la app, no el modelo
                // (ADR-0013). Decirlo aquí es parte de por qué se puede confiar.
                Text("""
                Cuando Lana te explica tu mes, las cifras las calcula la app: el modelo solo redacta \
                con números que ya salieron de tus movimientos.
                """)
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance(.noTabBar)
        }
        .background(lana.bg)
        .navigationTitle("Privacidad")
        .lanaInlineNavigationTitle()
        .hidesLanaTabBar()
    }
}

/// Qué es Lana, en una pantalla. El "cómo funciona" con el flujo detallado
/// vive en `LanaInfoView`.
struct AboutLanaView: View {
    @Environment(\.lana) private var lana

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                Image(systemName: "sparkles")
                    .font(.system(size: LanaMetrics.emptyStateIcon))
                    .foregroundStyle(lana.accent)
                    .accessibilityHidden(true)
                Text("Lana")
                    .lanaFont(.screenTitle)
                    .foregroundStyle(lana.ink)
                Text("""
                Le dices lo que gastaste con tus palabras y ella lo registra, aprende de tus \
                correcciones y te ayuda a llevar tus cuentas al día.
                """)
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance(.noTabBar)
        }
        .background(lana.bg)
        .navigationTitle("Acerca de Lana")
        .lanaInlineNavigationTitle()
        .hidesLanaTabBar()
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

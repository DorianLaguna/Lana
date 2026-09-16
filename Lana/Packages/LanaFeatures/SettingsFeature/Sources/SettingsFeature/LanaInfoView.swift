import LanaCore
import LanaDesign
import SwiftUI

/// "Cómo funciona Lana": explica en lenguaje de usuario qué hace el asistente
/// —no la IA por dentro— y el flujo hablas → entiende → registra, más el
/// aprendizaje por corrección (ADR-0012). Sin lógica: todo es texto fijo,
/// orientado a lo que Lana PUEDE hacer, nunca a modelos, prompts ni APIs
/// (ADR-0013: sin datos ni detalles técnicos en la superficie).
///
/// El botón de regresar lo da el `NavigationStack` de `SettingsView`, no se
/// dibuja a mano (mismo patrón que `CardDetailView`).
struct LanaInfoView: View {
    @Environment(\.lana) private var lana
    /// Salta a la pestaña Tarjetas, donde vive la guía de Apple Pay. `nil` en
    /// previews: entonces el puntero se queda como texto.
    private let onOpenCards: (() -> Void)?

    init(onOpenCards: (() -> Void)? = nil) {
        self.onOpenCards = onOpenCards
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg.rawValue) {
                header

                VStack(alignment: .leading, spacing: Space.md.rawValue) {
                    stepCard(
                        number: 1,
                        title: "Tú hablas",
                        detail: "«Gasté $250 en Oxxo»")
                    stepCard(
                        number: 2,
                        title: "Lana entiende",
                        detail: "Identifica el importe, el comercio y la categoría.")
                    stepCard(
                        number: 3,
                        title: "Lana registra",
                        detail: nil,
                        example: RegisteredExample(
                            merchant: "Oxxo",
                            amount: "$250",
                            category: "Comida"))
                }

                applePaySection

                manualEntrySection

                learningSection
            }
            .padding(Space.md.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle("Cómo funciona Lana")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [lana.accent, lana.highlight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
            Text("Lana es tu asistente financiero.")
                .lanaFont(.title)
                .foregroundStyle(lana.ink)
            Text("Le dices lo que gastaste con tus palabras y ella lo registra por ti.")
                .lanaFont(.body)
                .foregroundStyle(lana.ink50)
        }
    }

    private func stepCard(
        number: Int,
        title: String,
        detail: String?,
        example: RegisteredExample? = nil) -> some View {
        LanaCard {
            HStack(alignment: .top, spacing: Space.md.rawValue) {
                Text("\(number)")
                    .lanaFont(.headline)
                    .foregroundStyle(lana.accent)
                    .frame(width: 28, height: 28)
                    .background(lana.accent.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                    Text(title)
                        .lanaFont(.headline)
                        .foregroundStyle(lana.ink)
                    if let detail {
                        Text(detail)
                            .lanaFont(.body)
                            .foregroundStyle(lana.ink50)
                    }
                    if let example {
                        registeredExample(example)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func registeredExample(_ example: RegisteredExample) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(example.merchant)
                    .lanaFont(.body)
                    .foregroundStyle(lana.ink)
                // Sin color por categoría: ya no tienen uno propio (ADR-0044).
                Text(example.category)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.ink42)
            }
            Spacer()
            Text(example.amount)
                .lanaFont(.headline)
                .monospacedDigit()
                .foregroundStyle(lana.ink)
        }
        .padding(.top, Space.xs.rawValue)
    }

    /// Que el usuario sepa que no todo hay que dictarlo: los pagos con Apple
    /// Pay se registran solos, así que lo que de verdad conviene capturar por
    /// voz es el efectivo y las transferencias. Las instrucciones no se
    /// repiten aquí —viven en Tarjetas— solo se apunta a dónde encontrarlas.
    private var applePaySection: some View {
        LanaCard {
            HStack(alignment: .top, spacing: Space.md.rawValue) {
                Image(systemName: "creditcard.and.123")
                    .lanaFont(.headline)
                    .foregroundStyle(lana.accent)
                    .frame(width: 28, height: 28)
                    .background(lana.accent.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                    Text("Tus pagos con Apple Pay se registran solos")
                        .lanaFont(.headline)
                        .foregroundStyle(lana.ink)
                    Text("""
                    Si activas la captura automática, cada compra por contacto (NFC) con \
                    Apple Pay entra a Lana sin que la dictes. Así solo tienes que capturar \
                    a mano lo demás: el efectivo, las transferencias y lo que no pasa por \
                    tu iPhone.
                    """)
                    .lanaFont(.body)
                    .foregroundStyle(lana.ink50)
                    .fixedSize(horizontal: false, vertical: true)

                    // El puntero se puede tocar: quien busca Apple Pay desde
                    // Ajustes se quedaba a media frase, teniendo que salir y
                    // encontrar la pestaña por su cuenta.
                    if let onOpenCards {
                        Button(action: onOpenCards) {
                            Label("Ir a Tarjetas", systemImage: "creditcard")
                        }
                        .lanaFont(.body)
                        .foregroundStyle(lana.accent)
                        .padding(.top, Space.xs.rawValue)
                    } else {
                        Text("Encuentra cómo activarla en la pestaña Tarjetas → Configurar Apple Pay.")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.ink50)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Space.xs.rawValue)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// El registro a mano (ADR-0035). Existe y es deliberadamente secundario,
    /// pero quien no puede dictar —en una junta, sin permiso de micrófono, sin
    /// Apple Intelligence— no se entera de que está ahí si esta pantalla no lo
    /// nombra.
    private var manualEntrySection: some View {
        LanaCard {
            HStack(alignment: .top, spacing: Space.md.rawValue) {
                Image(systemName: "plus")
                    .lanaFont(.headline)
                    .foregroundStyle(lana.accent)
                    .frame(width: 28, height: 28)
                    .background(lana.accent.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                    Text("También puedes registrarlo a mano")
                        .lanaFont(.headline)
                        .foregroundStyle(lana.ink)
                    Text("""
                    El botón + del Dashboard abre el mismo formulario, en blanco: escribes \
                    el monto y el concepto tú. No pasa por el dictado, así que sirve \
                    cuando no puedes hablar.
                    """)
                    .lanaFont(.body)
                    .foregroundStyle(lana.ink50)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var learningSection: some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            Text("Lana aprende de tus correcciones")
                .lanaFont(.headline)
                .foregroundStyle(lana.ink)
            Text("""
            Cuando corriges la categoría de un gasto, Lana recuerda esa preferencia \
            para las próximas veces que menciones lo mismo.
            """)
            .lanaFont(.body)
            .foregroundStyle(lana.ink50)
        }
    }

    /// El ejemplo del paso 3: cómo queda un gasto ya registrado.
    private struct RegisteredExample {
        let merchant: String
        let amount: String
        let category: String
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            LanaInfoView(onOpenCards: {})
        }
        .lanaTheme(theme)
    }
}

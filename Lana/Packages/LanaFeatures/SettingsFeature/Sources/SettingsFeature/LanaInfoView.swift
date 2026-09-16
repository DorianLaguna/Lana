import LanaCore
import LanaDesign
import SwiftUI

/// "Cómo funciona Lana": qué hace el asistente en lenguaje de usuario —no la
/// IA por dentro— y el flujo hablas → entiende → registra, más el aprendizaje
/// por corrección (ADR-0012).
///
/// Todo es texto fijo y habla de lo que Lana puede hacer, nunca de modelos,
/// prompts ni APIs (ADR-0013). Se empuja desde Ajustes, así que no lleva barra.
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
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, Space.p26.rawValue)

                VStack(spacing: Space.p10.rawValue) {
                    stepCard(number: 1, title: "Tú hablas", detail: "«300 de súper y 120 en uber»")
                    stepCard(number: 2, title: "Lana entiende", detail: "Saca el monto, el concepto y la categoría.")
                    stepCard(
                        number: 3,
                        title: "Lana registra",
                        detail: nil,
                        example: RegisteredExample(merchant: "Súper", amount: "$300", category: "Despensa"))
                }
                .padding(.bottom, Space.p26.rawValue)

                infoCard(
                    icon: "creditcard.and.123",
                    title: "Tus pagos con Apple Pay se registran solos",
                    detail: """
                    Si activas la captura automática, cada compra por contacto entra a Lana sin que la \
                    dictes, marcada por revisar. Así solo capturas lo demás: efectivo, transferencias y \
                    lo que no pasa por tu iPhone.
                    """) {
                        // Se puede tocar: quien busca Apple Pay desde Ajustes se
                        // quedaba a media frase, teniendo que encontrar la
                        // pestaña por su cuenta.
                        if let onOpenCards {
                            Button("Ir a Tarjetas", action: onOpenCards)
                                .lanaFont(.bodyEmphasis)
                                .foregroundStyle(lana.accent)
                                .buttonStyle(.plain)
                                .frame(minHeight: LanaMetrics.minTouchTarget)
                        }
                    }
                    .padding(.bottom, Space.p10.rawValue)

                infoCard(
                    icon: "square.and.pencil",
                    title: "También puedes registrarlo a mano",
                    detail: """
                    Dentro de la hoja del micrófono, "Agregar a mano" abre el mismo formulario en \
                    blanco: escribes el monto y el concepto tú. No pasa por el dictado, así que sirve \
                    cuando no puedes hablar.
                    """) {
                        EmptyView()
                    }
                    .padding(.bottom, Space.p26.rawValue)

                SectionHeader("Lana aprende de tus correcciones", style: .minor)
                    .padding(.bottom, Space.sm.rawValue)
                Text("""
                Cuando corriges la categoría de un movimiento, Lana lo recuerda para las próximas veces \
                que menciones lo mismo.
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
        .navigationTitle("Cómo funciona Lana")
        .lanaInlineNavigationTitle()
        .hidesLanaTabBar()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            Image(systemName: "sparkles")
                .font(.system(size: LanaMetrics.emptyStateIcon))
                .foregroundStyle(lana.accent)
                .accessibilityHidden(true)
            Text("Hablas, entiende, registra.")
                .lanaFont(.screenTitle)
                .foregroundStyle(lana.ink)
            Text("Le dices lo que gastaste con tus palabras y ella lo registra por ti.")
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stepCard(
        number: Int,
        title: String,
        detail: String?,
        example: RegisteredExample? = nil) -> some View {
        LanaCard {
            HStack(alignment: .top, spacing: Space.p12.rawValue) {
                Text("\(number)")
                    .lanaFont(.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(lana.bg)
                    .frame(width: LanaMetrics.badge, height: LanaMetrics.badge)
                    .background(lana.accentFill, in: Circle())

                VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                    Text(title)
                        .lanaFont(.bodyEmphasis)
                        .foregroundStyle(lana.ink)
                    if let detail {
                        Text(detail)
                            .lanaFont(.explanation)
                            .foregroundStyle(lana.ink70)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let example {
                        registeredExample(example)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Cómo queda un movimiento ya registrado: la misma fila que se ve en Hoy.
    private func registeredExample(_ example: RegisteredExample) -> some View {
        MovementRow(
            title: example.merchant,
            subtitle: "\(example.category) · Efectivo",
            amountText: example.amount)
    }

    private func infoCard(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder action: () -> some View) -> some View {
        LanaCard {
            HStack(alignment: .top, spacing: Space.p12.rawValue) {
                Image(systemName: icon)
                    .lanaFont(.bodyEmphasis)
                    .foregroundStyle(lana.accent)
                    .frame(width: LanaMetrics.badge, height: LanaMetrics.badge)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                    Text(title)
                        .lanaFont(.bodyEmphasis)
                        .foregroundStyle(lana.ink)
                    Text(detail)
                        .lanaFont(.explanation)
                        .foregroundStyle(lana.ink70)
                        .fixedSize(horizontal: false, vertical: true)
                    action()
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// El ejemplo del paso 3.
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

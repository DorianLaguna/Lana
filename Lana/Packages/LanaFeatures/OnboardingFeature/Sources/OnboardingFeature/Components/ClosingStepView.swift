import LanaCore
import LanaDesign
import SwiftUI

/// Pantalla de cierre — lista cada paso de configuración completado con su
/// indicador de estado (R6.1) y describe el siguiente paso del onboarding. El
/// control de confirmar vive en `GuiaApplePayView`. Sin lógica: refleja el
/// resumen que le pasa el modelo. Los indicadores combinan ícono + texto,
/// nunca solo color (Docs/CONVENTIONS.md).
struct ClosingStepView: View {
    @Environment(\.lana) private var lana

    /// El resumen 1:1 con los pasos de configuración (R6.1).
    let summary: [GuiaApplePayModel.CompletionStep]
    /// `true` cuando el resumen no pudo cargarse (R6.2) — se muestra el mensaje
    /// y aun así el control de confirmar sigue disponible en la vista padre.
    let summaryUnavailable: Bool
    /// Cómo se presentó la guía — decide el texto de la nota final: en
    /// onboarding, "sigues con el resto de la configuración"; reabierta desde
    /// Tarjetas (`.standalone`), "vuelves a la app", porque ahí ya no hay nada
    /// más que configurar (R1.4).
    let mode: GuiaApplePayModel.Mode

    var body: some View {
        VStack(alignment: .leading, spacing: Space.p26.rawValue) {
            if summaryUnavailable {
                // R6.2: el resumen no está disponible, pero el flujo continúa —
                // el control de confirmar lo conserva la vista padre.
                GuideNotice(
                    systemImage: "exclamationmark.triangle",
                    message: "El resumen no pudo cargarse, pero puedes continuar.")
            } else {
                recap
                verification
            }

            // Tercer peso: una nota, no un bloque. Sin tarjeta ni icono.
            Text(nextStepMessage)
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink42)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Repaso, no verificación: Lana no puede comprobar que la automatización
    /// de Atajos exista (no hay API pública para consultarla — ver
    /// `ApplePayEnvironmentProbe`), así que esta lista solo recuerda lo que la
    /// guía pidió hacer. Plana y sin palomita verde ni "Completado": esa señal
    /// daba una falsa sensación de "verificado".
    private var recap: some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            Text("Estos son los pasos que cubrió la guía:")
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink60)
                .padding(.bottom, Space.xs.rawValue)

            VStack(spacing: 0) {
                ForEach(summary) { step in
                    HStack(alignment: .center, spacing: Space.p12.rawValue) {
                        GuideStepNumber(number: step.id)
                            .accessibilityHidden(true)
                        Text(step.title)
                            .lanaFont(.rowTitle)
                            .foregroundStyle(lana.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, Space.p10.rawValue)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Paso \(step.id): \(step.title)")

                    if step.id != summary.last?.id {
                        HairlineDivider(strong: true)
                    }
                }
            }
        }
    }

    /// Lo único accionable de la pantalla, y por eso lo único sobre `surface`:
    /// la comprobación real la hace el usuario.
    private var verification: some View {
        LanaCard {
            HStack(alignment: .firstTextBaseline, spacing: Space.p10.rawValue) {
                Image(systemName: "checkmark.seal")
                    .lanaFont(.bodyEmphasis)
                    .foregroundStyle(lana.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                    Text("¿Cómo saber si quedó bien?")
                        .lanaFont(.pushTitle)
                        .foregroundStyle(lana.ink)
                    Text("""
                    Lana no puede confirmar por su cuenta que la automatización \
                    haya quedado. La única forma segura es hacer un pago por \
                    contacto (NFC) con esa tarjeta: si aparece un gasto nuevo en \
                    Lana para revisar, funcionó.
                    """)
                    .lanaFont(.explanation)
                    .foregroundStyle(lana.ink70)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// La nota final depende de cómo se abrió la guía: en onboarding queda
    /// flujo por delante; reabierta desde Tarjetas solo se vuelve a la app.
    private var nextStepMessage: String {
        switch mode {
        case .onboarding:
            "A continuación seguirás con el resto de la configuración de Lana."
        case .standalone:
            "Ya quedó. Al confirmar, vuelves a la app."
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                ClosingStepView(
                    summary: GuiaApplePayContent.standard.shortcutSteps.map {
                        GuiaApplePayModel.CompletionStep(id: $0.id, title: $0.title, isCompleted: true)
                    },
                    summaryUnavailable: false,
                    mode: .onboarding)
                    .padding(LanaMetrics.onboardingMargin)
                    .background(LanaColors(theme: theme, colorScheme: .light).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

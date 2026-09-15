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
        VStack(alignment: .leading, spacing: Space.lg.rawValue) {
            Text("Repasa lo que configuraste")
                .lanaFont(.title)
                .foregroundStyle(lana.textPrimary)

            if summaryUnavailable {
                // R6.2: el resumen no está disponible, pero el flujo continúa —
                // el control de confirmar lo conserva la vista padre.
                LanaCard {
                    HStack(alignment: .top, spacing: Space.sm.rawValue) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(lana.warning)
                            .frame(width: 28)
                        Text("El resumen no pudo cargarse, pero puedes continuar.")
                            .lanaFont(.body)
                            .foregroundStyle(lana.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // Repaso, no verificación: Lana no puede comprobar que la
                // automatización de Atajos exista (no hay API pública para
                // consultarla — ver `ApplePayEnvironmentProbe`), así que esta
                // lista solo recuerda lo que la guía pidió hacer. Sin palomita
                // verde ni "Completado": esa señal daba una falsa sensación de
                // "verificado".
                Text("Estos son los pasos que cubrió la guía:")
                    .lanaFont(.body)
                    .foregroundStyle(lana.textSecondary)

                LanaCard {
                    VStack(spacing: 0) {
                        ForEach(summary) { step in
                            HStack(alignment: .top, spacing: Space.sm.rawValue) {
                                Image(systemName: "\(step.id).circle")
                                    .foregroundStyle(lana.textSecondary)
                                Text(step.title)
                                    .lanaFont(.body)
                                    .foregroundStyle(lana.textPrimary)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, Space.xs.rawValue)

                            if step.id != summary.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                // Lo honesto: la única comprobación real la hace el usuario.
                LanaCard {
                    HStack(alignment: .top, spacing: Space.sm.rawValue) {
                        Image(systemName: "checkmark.seal")
                            .foregroundStyle(lana.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                            Text("¿Cómo saber si quedó bien?")
                                .lanaFont(.headline)
                                .foregroundStyle(lana.textPrimary)
                            Text("""
                            Lana no puede confirmar por su cuenta que la automatización \
                            haya quedado. La única forma segura es hacer un pago por \
                            contacto (NFC) con esa tarjeta: si aparece un gasto nuevo en \
                            Lana para revisar, funcionó.
                            """)
                            .lanaFont(.body)
                            .foregroundStyle(lana.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            LanaCard {
                HStack(alignment: .top, spacing: Space.sm.rawValue) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(lana.accent)
                        .frame(width: 28)
                    Text(nextStepMessage)
                        .lanaFont(.body)
                        .foregroundStyle(lana.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .padding(Space.md.rawValue)
                    .background(LanaColors(theme: theme, colorScheme: .light).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

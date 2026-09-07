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

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg.rawValue) {
            Text("¡Listo!")
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
                Text("Configuraste estos pasos:")
                    .lanaFont(.body)
                    .foregroundStyle(lana.textSecondary)

                LanaCard {
                    VStack(spacing: 0) {
                        ForEach(summary) { step in
                            HStack(spacing: Space.sm.rawValue) {
                                // Ícono + etiqueta de estado: nunca solo color
                                // (Docs/CONVENTIONS.md).
                                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(step.isCompleted ? lana.positive : lana.textSecondary)
                                Text(step.title)
                                    .lanaFont(.body)
                                    .foregroundStyle(lana.textPrimary)
                                Spacer()
                                Text(step.isCompleted ? "Completado" : "Pendiente")
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.textSecondary)
                            }
                            .padding(.vertical, Space.xs.rawValue)

                            if step.id != summary.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            LanaCard {
                HStack(alignment: .top, spacing: Space.sm.rawValue) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(lana.accent)
                        .frame(width: 28)
                    Text("A continuación seguirás con el resto de la configuración de Lana.")
                        .lanaFont(.body)
                        .foregroundStyle(lana.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    summaryUnavailable: false)
                    .padding(Space.md.rawValue)
                    .background(LanaColors(theme: theme, colorScheme: .light).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

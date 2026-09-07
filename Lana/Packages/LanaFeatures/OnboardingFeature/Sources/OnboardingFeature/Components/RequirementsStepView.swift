import LanaCore
import LanaDesign
import SwiftUI

/// Pantalla de requisitos de dispositivo — dispositivo físico + limitación del
/// simulador (R5). Es SIEMPRE la primera pantalla de la guía, antes de
/// cualquier paso de configuración (R5.3). Sin lógica: solo dibuja el contenido
/// que le pasan (Docs/ARCHITECTURE.md, Docs/CONVENTIONS.md).
struct RequirementsStepView: View {
    @Environment(\.lana) private var lana

    /// El contenido estático de requisitos (R5.1, R5.2).
    let requirement: DeviceRequirement
    /// `true` cuando la guía corre en el simulador — se resalta la limitación
    /// (R5.2). El indicador combina ícono + texto, nunca solo color
    /// (Docs/CONVENTIONS.md).
    let isRunningInSimulator: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg.rawValue) {
            Text("Antes de empezar")
                .lanaFont(.title)
                .foregroundStyle(lana.textPrimary)

            LanaCard {
                requirementRow(
                    systemImage: "iphone",
                    message: requirement.physicalDeviceMessage)
            }

            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    requirementRow(
                        systemImage: "exclamationmark.triangle",
                        message: requirement.simulatorMessage)

                    if isRunningInSimulator {
                        Divider()
                        HStack(spacing: Space.sm.rawValue) {
                            Image(systemName: "xmark.octagon")
                                .foregroundStyle(lana.warning)
                            Text("Estás en el simulador: esta función no se puede probar aquí.")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.textSecondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func requirementRow(systemImage: String, message: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm.rawValue) {
            Image(systemName: systemImage)
                .foregroundStyle(lana.accent)
                .font(.system(size: 22))
                .frame(width: 28)
            Text(message)
                .lanaFont(.body)
                .foregroundStyle(lana.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                RequirementsStepView(
                    requirement: GuiaApplePayContent.standard.deviceRequirement,
                    isRunningInSimulator: theme == .cobalto)
                    .padding(Space.md.rawValue)
                    .background(LanaColors(theme: theme, colorScheme: .light).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

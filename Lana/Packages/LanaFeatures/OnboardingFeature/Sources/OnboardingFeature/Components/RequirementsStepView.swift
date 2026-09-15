import LanaCore
import LanaDesign
import SwiftUI

/// Pantalla de requisitos de dispositivo — dispositivo físico + limitación del
/// simulador (R5). Es SIEMPRE la primera pantalla de la guía, antes de
/// cualquier paso de configuración (R5.3). Sin lógica: solo dibuja el contenido
/// que le pasan (Docs/ARCHITECTURE.md, Docs/CONVENTIONS.md).
struct RequirementsStepView: View {
    @Environment(\.lana) private var lana

    /// El contenido estático de requisitos (R5.1).
    let requirement: DeviceRequirement
    /// `true` cuando la app corre en el simulador (R5.2). El aviso solo tiene
    /// sentido ahí: en un iPhone real, decir "esto no se puede probar en el
    /// simulador" es ruido.
    let isRunningInSimulator: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg.rawValue) {
            Text("Antes de empezar")
                .lanaFont(.title)
                .foregroundStyle(lana.textPrimary)

            LanaCard {
                requirementRow(
                    systemImage: "iphone",
                    tint: lana.accent,
                    message: requirement.physicalDeviceMessage)
            }

            // R5.2. El contenido siempre lo tuvo; hasta ahora ninguna vista lo
            // dibujaba, así que quien probaba en el simulador veía la guía
            // completa sin enterarse de que nada de eso podía funcionar ahí.
            if isRunningInSimulator {
                LanaCard {
                    requirementRow(
                        systemImage: "desktopcomputer",
                        tint: lana.warning,
                        message: requirement.simulatorMessage)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func requirementRow(systemImage: String, tint: Color, message: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm.rawValue) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.system(size: 22))
                .frame(width: 28)
            Text(message)
                .lanaFont(.body)
                .foregroundStyle(lana.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("En dispositivo") {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                RequirementsStepView(
                    requirement: GuiaApplePayContent.standard.deviceRequirement,
                    isRunningInSimulator: false)
                    .padding(Space.md.rawValue)
                    .background(LanaColors(theme: theme, colorScheme: .light).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

#Preview("En simulador (R5.2)") {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                RequirementsStepView(
                    requirement: GuiaApplePayContent.standard.deviceRequirement,
                    isRunningInSimulator: true)
                    .padding(Space.md.rawValue)
                    .background(LanaColors(theme: theme, colorScheme: .light).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

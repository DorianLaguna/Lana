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
        VStack(alignment: .leading, spacing: Space.p10.rawValue) {
            LanaCard {
                HStack(alignment: .firstTextBaseline, spacing: Space.p10.rawValue) {
                    Image(systemName: "iphone")
                        .lanaFont(.bodyEmphasis)
                        .foregroundStyle(lana.ink50)
                        .accessibilityHidden(true)
                    Text(requirement.physicalDeviceMessage)
                        .lanaFont(.explanation)
                        .foregroundStyle(lana.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // R5.2. Un aviso, no un segundo requisito: va sobre
            // `attentionSofter` y no en una tarjeta gemela, para que no se
            // lean como dos cosas que hay que cumplir.
            if isRunningInSimulator {
                GuideNotice(systemImage: "desktopcomputer", message: requirement.simulatorMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("En dispositivo") {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                RequirementsStepView(
                    requirement: GuiaApplePayContent.standard.deviceRequirement,
                    isRunningInSimulator: false)
                    .padding(LanaMetrics.onboardingMargin)
                    .background(LanaColors(theme: theme, colorScheme: .light).bg)
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
                    .padding(LanaMetrics.onboardingMargin)
                    .background(LanaColors(theme: theme, colorScheme: .light).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

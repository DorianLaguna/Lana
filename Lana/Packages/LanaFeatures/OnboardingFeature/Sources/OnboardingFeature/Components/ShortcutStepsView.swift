import LanaCore
import LanaDesign
import SwiftUI

/// Pantalla de pasos de Atajos — la secuencia numerada para armar la
/// automatización (R2.1) más el mapeo de parámetros Wallet → App Intent
/// (R2.3). Ofrece un enlace best-effort para abrir la app Atajos. Sin lógica:
/// refleja el contenido y llama el handler inyectado.
struct ShortcutStepsView: View {
    @Environment(\.lana) private var lana

    /// Pasos numerados y ordenados (R2.1).
    let steps: [GuiaStep]
    /// Mapeo de cada parámetro de Wallet al del App Intent (R2.3).
    let parameterMappings: [ParameterMapping]
    /// Abre la app Atajos (best-effort, inyectado desde `ContentView`); `nil`
    /// cuando el contenedor no lo cablea — entonces no se muestra el botón.
    let onOpenShortcutsApp: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg.rawValue) {
            Text("Arma la automatización")
                .lanaFont(.title)
                .foregroundStyle(lana.textPrimary)

            VStack(spacing: Space.sm.rawValue) {
                ForEach(steps) { step in
                    stepRow(step)
                }
            }

            parameterMappingCard

            if let onOpenShortcutsApp {
                Button(action: onOpenShortcutsApp) {
                    Label("Abrir la app Atajos", systemImage: "square.stack.3d.up")
                }
                .lanaFont(.body)
                .foregroundStyle(lana.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepRow(_ step: GuiaStep) -> some View {
        LanaCard {
            HStack(alignment: .top, spacing: Space.sm.rawValue) {
                // El número del paso + el ícono: la numeración de R2.1 se ve,
                // no depende solo del orden visual.
                ZStack {
                    Circle()
                        .fill(lana.accentMuted)
                        .frame(width: 32, height: 32)
                    Text("\(step.id)")
                        .lanaFont(.headline)
                        .foregroundStyle(lana.accent)
                }

                VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                    HStack(spacing: Space.xs.rawValue) {
                        Image(systemName: step.systemImage)
                            .foregroundStyle(lana.accent)
                        Text(step.title)
                            .lanaFont(.headline)
                            .foregroundStyle(lana.textPrimary)
                    }
                    Text(step.detail)
                        .lanaFont(.body)
                        .foregroundStyle(lana.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var parameterMappingCard: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                Text("Conecta los parámetros")
                    .lanaFont(.headline)
                    .foregroundStyle(lana.textPrimary)
                Text("En la acción de Lana, conecta cada dato que entrega Wallet a su parámetro:")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.textSecondary)

                ForEach(parameterMappings) { mapping in
                    HStack(spacing: Space.sm.rawValue) {
                        Text(mapping.walletLabel)
                            .lanaFont(.body)
                            .foregroundStyle(lana.textPrimary)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(lana.textSecondary)
                        Text(mapping.intentLabel)
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
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                ShortcutStepsView(
                    steps: GuiaApplePayContent.standard.shortcutSteps,
                    parameterMappings: GuiaApplePayContent.standard.parameterMappings,
                    onOpenShortcutsApp: {})
                    .padding(Space.md.rawValue)
                    .background(LanaColors(theme: theme, colorScheme: .light).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

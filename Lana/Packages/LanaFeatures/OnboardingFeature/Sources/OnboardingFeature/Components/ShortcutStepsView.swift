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
                .foregroundStyle(lana.ink)

            VStack(spacing: Space.sm.rawValue) {
                ForEach(steps) { step in
                    stepRow(step)
                }
            }

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
                            .foregroundStyle(lana.ink)
                    }
                    Text(step.detail)
                        .lanaFont(.body)
                        .foregroundStyle(lana.ink50)
                        .fixedSize(horizontal: false, vertical: true)

                    // El mapeo de parámetros pertenece a ESTE paso —el de
                    // agregar la acción de Lana—, no a una tarjeta suelta al
                    // final: es donde el usuario realmente conecta cada dato.
                    // Va como desplegable para no alargar el paso de golpe.
                    if step.attachesParameterMapping {
                        parameterMappingDisclosure
                            .padding(.top, Space.xs.rawValue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var parameterMappingDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                ForEach(parameterMappings) { mapping in
                    mappingRow(mapping)
                }
            }
            .padding(.top, Space.xs.rawValue)
        } label: {
            Text("Ver cómo conectar los parámetros")
                .lanaFont(.caption)
                .foregroundStyle(lana.accent)
        }
        .tint(lana.accent)
    }

    /// Un renglón del mapeo, en dos líneas. Antes era «origen → destino» en un
    /// `HStack`: con texto grande los dos nombres se truncaban justo donde
    /// importa, y son nombres que el usuario tiene que encontrar palabra por
    /// palabra dentro de la app Atajos. Por lo mismo el texto es seleccionable
    /// — así se pueden copiar sin que la feature toque UIKit.
    private func mappingRow(_ mapping: ParameterMapping) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("En Wallet: \(mapping.walletLabel)")
                .lanaFont(.caption)
                .foregroundStyle(lana.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: Space.xs.rawValue) {
                Image(systemName: "arrow.turn.down.right")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.accent)
                Text("En Lana: \(mapping.intentLabel)")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.ink50)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .background(LanaColors(theme: theme, colorScheme: .light).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

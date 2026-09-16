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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                stepRow(step, isLast: index == steps.count - 1)
            }

            if let onOpenShortcutsApp {
                Button(action: onOpenShortcutsApp) {
                    Label("Abrir la app Atajos", systemImage: "square.stack.3d.up")
                }
                .lanaFont(.action)
                .foregroundStyle(lana.accent)
                .buttonStyle(.plain)
                .frame(minHeight: LanaMetrics.minTouchTarget)
                .padding(.top, Space.sm.rawValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Un paso de la línea de tiempo: el número a la izquierda, unido al
    /// siguiente por una línea, y el contenido a la derecha.
    private func stepRow(_ step: GuiaStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.p14.rawValue) {
            VStack(spacing: Space.p6.rawValue) {
                GuideStepNumber(number: step.id)
                if !isLast {
                    Rectangle()
                        .fill(lana.hairlineStrong)
                        .frame(width: LanaMetrics.outline)
                        .frame(maxHeight: .infinity)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                HStack(alignment: .firstTextBaseline, spacing: Space.p6.rawValue) {
                    Image(systemName: step.systemImage)
                        .lanaFont(.footnote)
                        .foregroundStyle(lana.ink50)
                        .accessibilityHidden(true)
                    Text(step.title)
                        .lanaFont(.pushTitle)
                        .foregroundStyle(lana.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(step.detail)
                    .lanaFont(.explanation)
                    .foregroundStyle(lana.ink60)
                    .fixedSize(horizontal: false, vertical: true)

                // El mapeo de parámetros es el contenido de ESTE paso —el de
                // agregar la acción de Lana—, donde el usuario conecta cada
                // dato. Va a la vista: escondido en un desplegable, era lo
                // primero que se saltaba quien seguía la guía.
                if step.attachesParameterMapping {
                    parameterMapping
                        .padding(.top, Space.p6.rawValue)
                }
            }
            .padding(.bottom, isLast ? 0 : Space.lg.rawValue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Paso \(step.id)")
        }
    }

    private var parameterMapping: some View {
        LanaCard(padding: nil, radius: .inner) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(parameterMappings.enumerated()), id: \.element.id) { index, mapping in
                    mappingRow(mapping)
                        .padding(.horizontal, Space.p14.rawValue)
                        .padding(.vertical, Space.p12.rawValue)
                    if index < parameterMappings.count - 1 {
                        HairlineDivider()
                    }
                }
            }
        }
    }

    /// Un renglón del mapeo, en dos líneas. Antes era «origen → destino» en un
    /// `HStack`: con texto grande los dos nombres se truncaban justo donde
    /// importa, y son nombres que el usuario tiene que encontrar palabra por
    /// palabra dentro de la app Atajos. Por lo mismo el texto es seleccionable
    /// — así se pueden copiar sin que la feature toque UIKit.
    private func mappingRow(_ mapping: ParameterMapping) -> some View {
        VStack(alignment: .leading, spacing: Space.p2.rawValue) {
            Text("En Wallet: \(mapping.walletLabel)")
                .lanaFont(.bodyEmphasis)
                .foregroundStyle(lana.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: Space.xs.rawValue) {
                Image(systemName: "arrow.turn.down.right")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                    .accessibilityHidden(true)
                Text("En Lana: \(mapping.intentLabel)")
                    .lanaFont(.detail)
                    .foregroundStyle(lana.ink70)
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
                    .padding(LanaMetrics.onboardingMargin)
                    .background(LanaColors(theme: theme, colorScheme: .light).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

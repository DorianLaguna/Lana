import LanaCore
import LanaDesign
import SwiftUI

/// Pantalla de limitaciones conocidas — las seis cosas que el usuario debe
/// esperar de la captura automática para no confundirlas con un error (R4).
/// Sin lógica: solo dibuja el contenido. Cada limitación combina ícono + texto
/// (Docs/CONVENTIONS.md).
struct LimitationsStepView: View {
    @Environment(\.lana) private var lana

    /// Las limitaciones conocidas (R4.1–R4.6).
    let limitations: [KnownLimitation]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(limitations.enumerated()), id: \.element.id) { index, limitation in
                HStack(alignment: .firstTextBaseline, spacing: Space.p12.rawValue) {
                    Image(systemName: systemImage(for: limitation.kind))
                        .lanaFont(.bodyEmphasis)
                        .foregroundStyle(tint(for: limitation.kind))
                        .frame(width: LanaMetrics.badge)
                        .accessibilityHidden(true)
                    Text(limitation.message)
                        .lanaFont(.explanation)
                        .foregroundStyle(lana.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Space.p14.rawValue)
                .frame(maxWidth: .infinity, alignment: .leading)
                if index < limitations.count - 1 {
                    HairlineDivider(strong: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Un ícono distinto por tipo de limitación — refuerza el mensaje sin
    /// depender solo del color (Docs/CONVENTIONS.md).
    private func systemImage(for kind: KnownLimitation.Kind) -> String {
        switch kind {
        case .nfcOnly: "wave.3.right"
        case .needsReview: "checklist"
        case .rejectedTx: "xmark.circle"
        case .duplicateTx: "doc.on.doc"
        case .reviewEach: "magnifyingglass"
        case .manualIsPrimary: "hand.tap"
        case .emptyWalletVariables: "exclamationmark.triangle"
        }
    }

    private func tint(for kind: KnownLimitation.Kind) -> Color {
        switch kind {
        case .rejectedTx, .duplicateTx, .emptyWalletVariables: lana.attention
        default: lana.ink50
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LimitationsStepView(limitations: GuiaApplePayContent.standard.limitations)
                    .padding(LanaMetrics.onboardingMargin)
                    .background(LanaColors(theme: theme, colorScheme: .light).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

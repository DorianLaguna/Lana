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
        VStack(alignment: .leading, spacing: Space.lg.rawValue) {
            Text("Qué esperar")
                .lanaFont(.title)
                .foregroundStyle(lana.ink)

            VStack(spacing: Space.sm.rawValue) {
                ForEach(limitations) { limitation in
                    LanaCard {
                        HStack(alignment: .top, spacing: Space.sm.rawValue) {
                            Image(systemName: systemImage(for: limitation.kind))
                                .foregroundStyle(tint(for: limitation.kind))
                                .font(.system(size: 20))
                                .frame(width: 28)
                            Text(limitation.message)
                                .lanaFont(.body)
                                .foregroundStyle(lana.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
        default: lana.accent
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LimitationsStepView(limitations: GuiaApplePayContent.standard.limitations)
                    .padding(Space.md.rawValue)
                    .background(LanaColors(theme: theme, colorScheme: .light).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

import LanaCore
import LanaDesign
import SwiftUI

/// "Lo que encontré": los hallazgos calculados sobre el historial.
///
/// Cada tarjeta es un hecho con su cifra —no una frase redactada por el
/// modelo—, así que esta sección se ve igual con o sin Apple Intelligence. Van
/// arriba del resumen narrado a propósito: son lo que el usuario **no** sabía,
/// mientras que el resumen repite lo que ya vio en Mes.
///
/// Vive en `Components/` y no dentro de `InsightsView` porque no tiene estado
/// propio y porque la vista ya estaba en el límite de tamaño (`swiftlint`).
struct FindingsSection: View {
    @Environment(\.lana) private var lana

    let findings: [Finding]

    var body: some View {
        if !findings.isEmpty {
            SectionHeader("Lo que encontré", style: .minor)
                .padding(.bottom, Space.p12.rawValue)
            VStack(spacing: Space.p10.rawValue) {
                ForEach(findings) { finding in
                    card(finding)
                }
            }
            .padding(.bottom, Space.p26.rawValue)
        }
    }

    private func card(_ finding: Finding) -> some View {
        LanaCard(padding: .p14, radius: .inner) {
            VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                Text(finding.headline)
                    .lanaFont(.bodyEmphasis)
                    .foregroundStyle(lana.ink)
                if let detail = finding.detail {
                    Text(detail)
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink50)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                VStack(alignment: .leading, spacing: 0) {
                    FindingsSection(findings: [
                        Finding(
                            kind: .pace,
                            headline: "Vas $1,200.00 arriba de como ibas el 15 de agosto",
                            detail: "Hasta hoy llevas $8,400.00; a estas alturas del mes pasado, $7,200.00.",
                            magnitude: 1200,
                            currency: .mxn),
                        Finding(
                            kind: .repeatedCharges,
                            headline: "4 cobros se repiten cada mes: $1,240.00",
                            detail: "Gimnasio, Netflix, Spotify, iCloud. No están dados de alta como recurrentes.",
                            magnitude: 1240,
                            currency: .mxn)
                    ])
                }
                .padding(LanaMetrics.screenMargin)
                .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                .lanaTheme(theme)
            }
        }
    }
}

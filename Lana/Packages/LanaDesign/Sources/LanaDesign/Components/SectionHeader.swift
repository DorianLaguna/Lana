import SwiftUI

/// El encabezado de una sección: "ESTA QUINCENA", "EN QUÉ SE FUE", "LUNES 14".
///
/// Va sobre el fondo, fuera de las tarjetas — la sección se nombra una vez y
/// su contenido no repite el título. Admite una acción de texto a la derecha
/// ("Ver el mes") cuando la sección tiene un destino obvio.
public struct SectionHeader: View {
    /// Cuánto pesa el encabezado.
    public enum Style: Sendable {
        /// 13 pt semibold `ink50`: secciones de primer nivel.
        case standard
        /// 12 pt bold `ink42`: encabezados menores (días en un detalle).
        case minor
        /// 12 pt bold `attention`: una sección que reclama acción (PENDIENTES).
        case attention
    }

    @Environment(\.lana) private var lana

    private let title: String
    private let style: Style
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(_ title: String, style: Style = .standard, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
            Text(title)
                .lanaFont(style == .standard ? .sectionHeader : .minorHeader)
                .foregroundStyle(titleColor)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.sm.rawValue)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .lanaFont(.footnote)
                    .foregroundStyle(lana.accent)
                    .buttonStyle(.plain)
                    .frame(minHeight: LanaMetrics.minTouchTarget)
                    .contentShape(Rectangle())
            }
        }
    }

    private var titleColor: Color {
        switch style {
        case .standard: lana.ink50
        case .minor: lana.ink42
        case .attention: lana.attention
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Space.lg.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                SectionHeader("Hoy", actionTitle: "Ver el mes", action: {})
                SectionHeader("Lunes 14", style: .minor)
                SectionHeader("Pendientes", style: .attention)
            }
            .lanaTheme(theme)
        }
    }
    .padding(LanaMetrics.screenMargin)
}

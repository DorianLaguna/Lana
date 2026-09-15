import SwiftUI

/// El tono de un dato secundario: el valor a la derecha de una fila de acceso
/// o el subtítulo de una fila de Ajustes.
public enum LanaTone: Sendable, Equatable {
    /// `ink42`: informativo.
    case muted
    /// `ink35`: apagado, deshabilitado.
    case disabled
    /// `attention`: reclama acción ("3 pendientes").
    case attention
    /// `positive`: está bien ("Permitido", "iCloud al día").
    case positive
}

extension LanaColors {
    func color(for tone: LanaTone) -> Color {
        switch tone {
        case .muted: ink42
        case .disabled: ink35
        case .attention: attention
        case .positive: positive
        }
    }
}

/// Una fila que lleva a otra pantalla y **adelanta la respuesta**: "Recurrentes
/// · 3 pendientes ›". Reemplaza a los iconos sin nombre: la fila dice qué hay
/// dentro y ya muestra un dato real.
///
/// Va dentro de una `LanaCard` sin padding (`LanaCard(padding: nil)`), con
/// `HairlineDivider` entre filas.
public struct NavRow: View {
    @Environment(\.lana) private var lana

    private let title: String
    private let subtitle: String?
    private let subtitleTone: LanaTone
    private let value: String?
    private let valueTone: LanaTone
    private let isDimmed: Bool
    private let showsChevron: Bool
    private let action: () -> Void

    /// - Parameters:
    ///   - subtitle: una línea bajo el título ("15 palabras aprendidas").
    ///   - value: el dato a la derecha ("68% crédito").
    ///   - isDimmed: el título en `ink35` — una función no disponible.
    public init(
        _ title: String,
        subtitle: String? = nil,
        subtitleTone: LanaTone = .muted,
        value: String? = nil,
        valueTone: LanaTone = .muted,
        isDimmed: Bool = false,
        showsChevron: Bool = true,
        action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleTone = subtitleTone
        self.value = value
        self.valueTone = valueTone
        self.isDimmed = isDimmed
        self.showsChevron = showsChevron
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Space.p10.rawValue) {
                VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                    Text(title)
                        .lanaFont(.label)
                        .foregroundStyle(isDimmed ? lana.ink35 : lana.ink)
                    if let subtitle {
                        Text(subtitle)
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.color(for: subtitleTone))
                    }
                }
                Spacer(minLength: Space.sm.rawValue)
                if let value {
                    Text(value)
                        .lanaFont(.detail)
                        .monospacedDigit()
                        .foregroundStyle(lana.color(for: valueTone))
                }
                if showsChevron {
                    RowChevron()
                }
            }
            .padding(Space.md.rawValue)
            .frame(minHeight: LanaMetrics.minRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// El chevron de una fila que navega.
public struct RowChevron: View {
    @Environment(\.lana) private var lana

    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .lanaFont(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(lana.ink35)
            .accessibilityHidden(true)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.lg.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard(padding: nil) {
                    VStack(spacing: 0) {
                        NavRow("Formas de pago", value: "68% crédito", action: {})
                        HairlineDivider()
                        NavRow("Recurrentes", value: "3 pendientes", valueTone: .attention, action: {})
                        HairlineDivider()
                        NavRow(
                            "Análisis con Lana",
                            subtitle: "Necesita Apple Intelligence",
                            subtitleTone: .disabled,
                            isDimmed: true,
                            action: {})
                    }
                }
                .lanaTheme(theme)
            }
        }
        .padding(LanaMetrics.screenMargin)
    }
}

import SwiftUI

/// Una cápsula chica: un atributo de un borrador ("Despensa › Súper", "Hoy"),
/// una duda ("Falta forma de pago") o una pregunta sugerida.
public struct Chip: View {
    /// El aspecto del chip.
    public enum Tone: Sendable {
        /// `surface2` con `ink`: un atributo ya resuelto.
        case neutral
        /// `attentionChip` con `attention`: falta un dato o no hubo certeza.
        case doubt
        /// `bg` con `ink70`, más grande: un atajo (pregunta sugerida).
        case suggestion
    }

    @Environment(\.lana) private var lana

    private let label: String
    private let systemImage: String?
    private let tone: Tone
    private let action: (() -> Void)?

    public init(_ label: String, systemImage: String? = nil, tone: Tone = .neutral, action: (() -> Void)? = nil) {
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { chip }
                .buttonStyle(.plain)
                // El chip mide 34 pt; el área de toque llega a 44.
                .padding(.vertical, Space.p5.rawValue)
                .contentShape(Rectangle())
                .padding(.vertical, -Space.p5.rawValue)
        } else {
            chip
        }
    }

    private var chip: some View {
        HStack(spacing: Space.xs.rawValue) {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(label)
        }
        .lanaFont(tone == .suggestion ? .detail : .rowSubtitle)
        .foregroundStyle(foreground)
        .padding(.vertical, (tone == .suggestion ? Space.p9 : Space.p6).rawValue)
        .padding(.horizontal, (tone == .suggestion ? Space.p14 : Space.p11).rawValue)
        .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .neutral: lana.ink
        case .doubt: lana.attention
        case .suggestion: lana.ink70
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: lana.surface2
        case .doubt: lana.attentionChip
        case .suggestion: lana.bg
        }
    }
}

/// Acomoda vistas en renglones que se parten cuando ya no caben — los chips
/// de un borrador.
public struct FlowLayout: SwiftUI.Layout {
    private let spacing: CGFloat

    public init(spacing: Space = .p7) {
        self.spacing = spacing.rawValue
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var cursorY = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var cursorX = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: cursorX, y: cursorY), proposal: ProposedViewSize(size))
                cursorX += size.width + spacing
            }
            cursorY += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = rows[rows.count - 1].indices.isEmpty
                ? size.width
                : rows[rows.count - 1].width + spacing + size.width
            if proposedWidth > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let current = rows.count - 1
            rows[current].width = rows[current].indices.isEmpty ? size.width : rows[current].width + spacing + size
                .width
            rows[current].height = max(rows[current].height, size.height)
            rows[current].indices.append(index)
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.lg.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                FlowLayout {
                    Chip("Gasto", action: {})
                    Chip("Despensa › Súper", action: {})
                    Chip("Hoy", action: {})
                    Chip("Falta forma de pago", tone: .doubt, action: {})
                    Chip("¿Cuánto debo en mis tarjetas?", tone: .suggestion, action: {})
                }
                .padding(LanaMetrics.screenMargin)
                .background(LanaColors(theme: theme, colorScheme: .dark).surface)
                .lanaTheme(theme)
            }
        }
    }
}

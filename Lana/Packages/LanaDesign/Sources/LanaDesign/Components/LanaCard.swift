import SwiftUI

/// Una tarjeta o agrupación sobre el fondo: `surface`, radio 16, **sin
/// sombra** — la jerarquía la da el fondo, no la elevación (ADR-0044).
public struct LanaCard<Content: View>: View {
    @Environment(\.lana) private var lana
    private let padding: Space?
    private let radius: Radius
    private let fill: Fill
    private let content: Content

    /// El fondo de la tarjeta.
    public enum Fill: Sendable {
        /// `surface`: lo normal.
        case surface
        /// `surfaceDim`: algo que ya no pide nada (una tarjeta sin deuda).
        case dim
        /// `bg`: un bloque dentro de una hoja `surface` (borradores, respuestas).
        case background
        /// `attentionSoft`: reclama acción (Por revisar, ritmo excedido).
        case attention
        /// `accentSoft`: invita (Apple Pay sin configurar).
        case accent
    }

    /// - Parameters:
    ///   - padding: `nil` para contenido que maneja su propio padding (filas
    ///     `NavRow` con divisores de borde a borde).
    ///   - radius: `.card` (16), `.cardLarge` (18) o `.inner` (14).
    public init(
        padding: Space? = .md,
        radius: Radius = .card,
        fill: Fill = .surface,
        @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.fill = fill
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding?.rawValue ?? 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: radius.rawValue, style: .continuous))
    }

    private var background: Color {
        switch fill {
        case .surface: lana.surface
        case .dim: lana.surfaceDim
        case .background: lana.bg
        case .attention: lana.attentionSoft
        case .accent: lana.accentSoft
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.p10.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    Text(theme.displayName)
                        .lanaFont(.rowTitle)
                }
                .lanaTheme(theme)
            }
        }
        .padding(LanaMetrics.screenMargin)
    }
}

import SwiftUI

/// Los botones en cápsula de la app. Nunca rojo: borrar es un swipe o un
/// `role: .destructive` del sistema.
public struct LanaButtonStyle: ButtonStyle {
    /// Qué tan importante es la acción.
    public enum Kind: Sendable {
        /// Relleno del acento: "Guardar los 2", "Registrar pago".
        case primary
        /// `surface2` con `ink70`: "Seguir dictando", "Pagar todo".
        case secondary
        /// Relleno `attention` con texto `bg`: "Registrar hoy".
        case attention
    }

    /// Qué tan grande es.
    public enum Size: Sendable {
        /// 16 pt, padding 16: el pie de una hoja o de la guía.
        case large
        /// 15 pt, padding 14: acciones dentro de una pantalla.
        case regular
        /// 13.5 pt, padding 9: el botón ancho de un pendiente.
        case medium
        /// 13 pt, padding 7/14: "Liquidar" dentro de una fila.
        case compact
    }

    private let kind: Kind
    private let size: Size
    private let isExpanded: Bool

    /// - Parameter isExpanded: ocupa todo el ancho disponible.
    public init(_ kind: Kind = .primary, size: Size = .regular, isExpanded: Bool = false) {
        self.kind = kind
        self.size = size
        self.isExpanded = isExpanded
    }

    public func makeBody(configuration: Configuration) -> some View {
        LanaButtonBody(configuration: configuration, kind: kind, size: size, isExpanded: isExpanded)
    }
}

private struct LanaButtonBody: View {
    @Environment(\.lana) private var lana
    @Environment(\.isEnabled) private var isEnabled

    let configuration: ButtonStyleConfiguration
    let kind: LanaButtonStyle.Kind
    let size: LanaButtonStyle.Size
    let isExpanded: Bool

    var body: some View {
        configuration.label
            .lanaFont(font)
            .fontWeight(kind == .secondary ? .medium : .semibold)
            .foregroundStyle(foreground)
            .padding(.vertical, verticalPadding.rawValue)
            .padding(.horizontal, horizontalPadding.rawValue)
            .frame(maxWidth: isExpanded ? .infinity : nil)
            .background(background, in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : (isEnabled ? 1 : 0.5))
    }

    private var font: LanaTextStyle {
        switch size {
        case .large: .pushTitle
        case .regular: .action
        case .medium: .detail
        case .compact: .footnote
        }
    }

    private var verticalPadding: Space {
        switch size {
        case .large: .md
        case .regular: .p14
        case .medium: .p9
        case .compact: .p7
        }
    }

    private var horizontalPadding: Space {
        switch size {
        case .large: .p18
        case .regular: .p18
        case .medium: .p14
        case .compact: .p14
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: lana.onAccent
        case .secondary: lana.ink70
        case .attention: lana.bg
        }
    }

    private var background: Color {
        switch kind {
        case .primary: lana.accentFill
        case .secondary: lana.surface2
        case .attention: lana.attention
        }
    }
}

public extension ButtonStyle where Self == LanaButtonStyle {
    /// Un botón en cápsula de Lana.
    static func lana(
        _ kind: LanaButtonStyle.Kind = .primary,
        size: LanaButtonStyle.Size = .regular,
        isExpanded: Bool = false) -> LanaButtonStyle {
        LanaButtonStyle(kind, size: size, isExpanded: isExpanded)
    }
}

/// Un avatar circular con la inicial de una persona.
public struct InitialAvatar: View {
    @Environment(\.lana) private var lana

    private let name: String
    private let diameter: CGFloat
    private let isRaised: Bool

    /// - Parameters:
    ///   - diameter: `LanaMetrics.avatarSmall`, `avatarLarge` o `avatarStacked`.
    ///   - isRaised: `surface3` (sobre una tarjeta) en vez de `surface2`.
    public init(name: String, diameter: CGFloat = LanaMetrics.avatarSmall, isRaised: Bool = false) {
        self.name = name
        self.diameter = diameter
        self.isRaised = isRaised
    }

    public var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "·")
            .lanaFont(diameter >= LanaMetrics.avatarLarge ? .pushTitle : .caption2)
            .fontWeight(.semibold)
            .foregroundStyle(lana.ink70)
            .frame(width: diameter, height: diameter)
            .background(isRaised ? lana.surface3 : lana.surface2, in: Circle())
            .accessibilityLabel(name)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.lg.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                VStack(spacing: Space.p10.rawValue) {
                    HStack(spacing: Space.p10.rawValue) {
                        Button("Seguir dictando") {}
                            .buttonStyle(.lana(.secondary, size: .large))
                        Button("Guardar los 2") {}
                            .buttonStyle(.lana(size: .large, isExpanded: true))
                    }
                    Button("Registrar hoy") {}
                        .buttonStyle(.lana(.attention, size: .medium, isExpanded: true))
                    HStack {
                        InitialAvatar(name: "Dorian")
                        InitialAvatar(name: "Renata", diameter: LanaMetrics.avatarLarge, isRaised: true)
                        Spacer()
                        Button("Liquidar") {}
                            .buttonStyle(.lana(size: .compact))
                    }
                }
                .padding(LanaMetrics.screenMargin)
                .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                .lanaTheme(theme)
            }
        }
    }
}

import SwiftUI

/// Un estado vacío o de limitación: icono apagado, título, dos líneas que
/// dicen qué hacer y **un solo** botón (ADR-0044, sección 14 del rediseño).
///
/// Nunca en color: una limitación (sin Apple Intelligence, sin permiso) no es
/// una función premium. Nunca un tono de regaño: es información.
///
/// La única excepción al botón único es `secondaryActionTitle`, la salida en
/// texto a "Agregar a mano" de los estados donde no se puede dictar — la app
/// tiene que seguir siendo usable.
public struct EmptyStateView: View {
    @Environment(\.lana) private var lana

    private let systemImage: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?
    private let secondaryActionTitle: String?
    private let secondaryAction: (() -> Void)?
    private let showsProgress: Bool

    /// - Parameters:
    ///   - showsProgress: una barra indeterminada bajo el texto (el modelo se
    ///     está descargando).
    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        showsProgress: Bool = false) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.showsProgress = showsProgress
    }

    public var body: some View {
        VStack(spacing: Space.p12.rawValue) {
            Image(systemName: systemImage)
                .font(.system(size: LanaMetrics.emptyStateIcon))
                .foregroundStyle(lana.ink35)
                .padding(.bottom, Space.xs.rawValue)
                .accessibilityHidden(true)

            Text(title)
                .lanaFont(.screenTitle)
                .foregroundStyle(lana.ink)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .lanaFont(.explanation)
                    .foregroundStyle(lana.ink50)
                    .multilineTextAlignment(.center)
            }

            if showsProgress {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(lana.accentFill)
                    .padding(.top, Space.xs.rawValue)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.lana())
                    .padding(.top, Space.sm.rawValue)
            }

            if let secondaryActionTitle, let secondaryAction {
                Button(secondaryActionTitle, action: secondaryAction)
                    .lanaFont(.bodyEmphasis)
                    .foregroundStyle(lana.accent)
                    .buttonStyle(.plain)
                    .frame(minHeight: LanaMetrics.minTouchTarget)
            }
        }
        .frame(maxWidth: LanaMetrics.emptyStateMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl.rawValue)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                VStack {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "Aún no compartes gastos",
                        message: "Crea una lista para repartir la renta, un viaje o el súper.",
                        actionTitle: "Crear una lista",
                        action: {})
                    EmptyStateView(
                        systemImage: "sparkles",
                        title: "Lana se está preparando",
                        message: "El modelo de voz se está descargando. Puede tardar unos minutos.",
                        secondaryActionTitle: "Agregar a mano",
                        secondaryAction: {},
                        showsProgress: true)
                }
                .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                .lanaTheme(theme)
            }
        }
    }
}

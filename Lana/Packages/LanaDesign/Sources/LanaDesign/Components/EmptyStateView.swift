import SwiftUI

/// Un estado vacío — sin gastos del mes, bandeja de revisión limpia, sin
/// resultados de búsqueda. Nunca un tono de regaño: es información, no un
/// reproche por no haber usado la app (Docs/.claude/skills/theming → Tono).
public struct EmptyStateView: View {
    @Environment(\.lana) private var lana

    private let systemImage: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Space.sm.rawValue) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(lana.textSecondary)

            Text(title)
                .lanaFont(.headline)
                .foregroundStyle(lana.textPrimary)

            if let message {
                Text(message)
                    .lanaFont(.body)
                    .foregroundStyle(lana.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .lanaFont(.body)
                    .foregroundStyle(lana.accent)
                    .padding(.top, Space.xs.rawValue)
            }
        }
        .padding(Space.xl.rawValue)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    EmptyStateView(
                        systemImage: "tray",
                        title: "Sin gastos este mes",
                        message: "Cuando registres algo, aparece aquí.",
                        actionTitle: "Agregar gasto",
                        action: {})
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

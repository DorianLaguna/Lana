import SwiftUI

/// La superficie elevada base — tarjetas, hojas, cualquier contenido que
/// necesite separarse del fondo de pantalla.
public struct LanaCard<Content: View>: View {
    @Environment(\.lana) private var lana
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Space.md.rawValue)
            .background(lana.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Space.sm.rawValue, style: .continuous))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    Text(theme.displayName)
                        .lanaFont(.headline)
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

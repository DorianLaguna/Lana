import SwiftUI

/// El campo de entrada base de la app — la captura por texto (Fase 5) y
/// cualquier formulario lo usan. Un borde de `accent` al enfocar, nunca un
/// color literal.
public struct LanaTextField: View {
    @Environment(\.lana) private var lana
    @FocusState private var isFocused: Bool

    private let placeholder: String
    @Binding private var text: String

    public init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .lanaFont(.body)
            .foregroundStyle(lana.textPrimary)
            .padding(Space.sm.rawValue)
            .background(lana.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Space.xs.rawValue, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Space.xs.rawValue, style: .continuous)
                    .strokeBorder(isFocused ? lana.accent : lana.separator, lineWidth: isFocused ? 2 : 1))
            .focused($isFocused)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    LanaTextField("Gasté 300 en súper", text: .constant(""))
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

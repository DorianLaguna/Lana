import SwiftUI

/// El campo de texto de la app: el mismo alto y el mismo borde en toda ella,
/// con el acento marcando el foco. Es el que usan los formularios que no son
/// la captura por voz.
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
            .lanaFont(.rowTitle)
            .foregroundStyle(lana.ink)
            .padding(.vertical, Space.p10.rawValue)
            .padding(.horizontal, Space.p12.rawValue)
            .frame(minHeight: LanaMetrics.minTouchTarget)
            .background(lana.surface2, in: RoundedRectangle(cornerRadius: Radius.block.rawValue, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.block.rawValue, style: .continuous)
                    .strokeBorder(
                        isFocused ? lana.accent : lana.hairlineStrong,
                        lineWidth: isFocused ? LanaMetrics.outline : LanaMetrics.hairline))
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

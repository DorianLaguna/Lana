import SwiftUI

/// El encabezado de una sección dentro de una `LanaCard`.
///
/// Es la forma que la app repite en todas sus tarjetas agrupadoras ("Por
/// categoría", "Por forma de pago", "Recurrentes", "Saldos"): `.caption` en
/// `textSecondary`, sin más adorno. Vive en `LanaDesign` porque lo necesitan
/// varias features y estas no pueden importarse entre sí
/// (Docs/ARCHITECTURE.md).
public struct SectionCaption: View {
    @Environment(\.lana) private var lana

    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .lanaFont(.caption)
            .foregroundStyle(lana.textSecondary)
    }
}

#Preview {
    VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    SectionCaption("Por categoría")
                    Text("Contenido de la sección")
                        .lanaFont(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .lanaTheme(theme)
        }
    }
    .padding(Space.md.rawValue)
}

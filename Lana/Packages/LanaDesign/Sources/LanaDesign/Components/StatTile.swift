import SwiftUI

/// La caja de color con un título chico y una cifra encima de un tinte.
///
/// Es la pieza que el Dashboard usa para "Gastado" e "Ingresos". El
/// `.opacity(0.8)` del título es lo que le da jerarquía sobre un fondo teñido
/// sin recurrir a un segundo color: el mismo tono, más apagado.
///
/// Es para **resúmenes**, no para el número principal de una pantalla de
/// detalle: ahí va `.largeAmount`, que es el único tipo redondeado del sistema
/// y está reservado para la cifra que la pantalla vino a contestar.
public struct StatTile: View {
    private let title: String
    private let value: String
    private let tint: Color
    private let onTint: Color

    public init(title: String, value: String, tint: Color, onTint: Color) {
        self.title = title
        self.value = value
        self.tint = tint
        self.onTint = onTint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            Text(title)
                .lanaFont(.caption)
                .foregroundStyle(onTint.opacity(0.8))
            Text(value)
                .lanaFont(.headline)
                .monospacedDigit()
                .foregroundStyle(onTint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md.rawValue)
        .background(tint, in: RoundedRectangle(cornerRadius: Space.sm.rawValue, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                ThemedTilePair()
                    .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

/// El par tal como lo usa el Dashboard — hace falta una vista aparte para poder
/// leer `\.lana` ya con el tema aplicado.
private struct ThemedTilePair: View {
    @Environment(\.lana) private var lana

    var body: some View {
        LanaCard {
            HStack(spacing: Space.sm.rawValue) {
                StatTile(title: "Gastado", value: "$12,360.00", tint: lana.accent, onTint: .white)
                StatTile(
                    title: "Ingresos",
                    value: "$18,000.00",
                    tint: lana.positive.opacity(0.12),
                    onTint: lana.positive)
            }
        }
    }
}

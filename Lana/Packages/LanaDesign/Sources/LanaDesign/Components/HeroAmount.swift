import SwiftUI

/// La cifra que una pantalla vino a contestar: etiqueta chica, monto grande,
/// contexto chico debajo.
///
/// Es la forma con la que abren todos los drill-downs de la app — el detalle de
/// una categoría, el de una forma de pago, el de una tarjeta. Usa
/// `.largeAmount`, el único tipo redondeado del sistema, reservado para dinero.
/// El `spacing: Space.xs` es parte del patrón: la etiqueta, el monto y el
/// contexto son **una sola cosa**, y separarlos más los volvería tres.
///
/// Si una pantalla de detalle no abre con esto, lo primero que ve el ojo acaba
/// siendo el chrome (un selector, una fila de etiquetas) en vez del dato — que
/// es justo lo que `.claude/agents/design-reviewer.md` llama una pantalla plana.
public struct HeroAmount: View {
    @Environment(\.lana) private var lana

    private let label: String
    private let amount: String
    private let context: String?

    /// - Parameters:
    ///   - label: qué es la cifra ("Gastado en 2026", "Total en el mes").
    ///   - amount: el monto, ya formateado por quien conoce la moneda.
    ///   - context: una línea que la sitúe ("9 meses con movimiento"). `nil` la
    ///     omite en vez de dejar un hueco.
    public init(label: String, amount: String, context: String? = nil) {
        self.label = label
        self.amount = amount
        self.context = context
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            Text(label)
                .lanaFont(.caption)
                .foregroundStyle(lana.textSecondary)
            Text(amount)
                .lanaFont(.largeAmount)
                .monospacedDigit()
                .foregroundStyle(lana.textPrimary)
            if let context {
                Text(context)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    HeroAmount(
                        label: "Gastado en 2026",
                        amount: "$148,320.00",
                        context: "9 meses con movimiento")
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

import SwiftUI

/// Un renglón de "etiqueta a la izquierda, cifra a la derecha".
///
/// Es la fila más repetida de la app — el desglose por subcategoría, el detalle
/// de una tarjeta, los pagos próximos. La cifra siempre lleva dígitos tabulares
/// y va alineada a la derecha: sin eso los números bailan entre renglones y una
/// lista se ve descuidada (`.claude/skills/theming/SKILL.md`).
///
/// Solo recibe primitivos: `LanaDesign` no conoce el dominio, así que quien la
/// usa decide cómo formatear el monto.
public struct LabeledStatRow: View {
    @Environment(\.lana) private var lana

    private let title: String
    private let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        HStack {
            Text(title)
                .lanaFont(.body)
                .foregroundStyle(lana.textPrimary)
            Spacer(minLength: Space.sm.rawValue)
            Text(value)
                .lanaFont(.body)
                .monospacedDigit()
                .foregroundStyle(lana.textPrimary)
        }
        // Una fila sola es un dato; la etiqueta y su cifra son una sola cosa
        // para VoiceOver, no dos.
        .accessibilityElement(children: .combine)
    }
}

/// Varias `LabeledStatRow` con una línea entre ellas y ninguna al final.
///
/// Encapsula el idiom que la app repite a mano en cinco lugares
/// (`RecurringItemsSection`, `UpcomingCardPaymentsSection`, `BalancesView`,
/// `SharedListDetailView`, `DebtDetailView`): `VStack(spacing: 0)` con un
/// `Divider()` entre filas. El `spacing: 0` es parte del patrón — con las
/// líneas dibujadas, el aire extra las despega de lo que separan.
public struct StatRowGroup: View {
    /// Una fila del grupo. Lleva `id` propio para poder recorrerse sin exigir
    /// que las etiquetas sean únicas: dos meses pueden llamarse igual en dos
    /// bloques distintos.
    public struct Row: Identifiable, Sendable {
        public let id = UUID()
        public let title: String
        public let value: String

        public init(title: String, value: String) {
            self.title = title
            self.value = value
        }
    }

    private let rows: [Row]

    public init(_ rows: [Row]) {
        self.rows = rows
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                LabeledStatRow(title: row.title, value: row.value)
                    .padding(.vertical, Space.xs.rawValue)
                if row.id != rows.last?.id {
                    Divider()
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                        SectionCaption("Mes a mes")
                        StatRowGroup([
                            StatRowGroup.Row(title: "Promedio mensual", value: "$12,360.00"),
                            StatRowGroup.Row(title: "Mes más caro", value: "Agosto · $18,940.00"),
                            StatRowGroup.Row(title: "Mes más barato", value: "Febrero · $7,120.00")
                        ])
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

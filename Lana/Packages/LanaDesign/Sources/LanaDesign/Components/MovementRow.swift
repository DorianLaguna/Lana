import SwiftUI

/// Una fila de movimiento — la unidad más repetida de la app (Hoy, Mes, el
/// detalle de una tarjeta o de una lista). Título, "Categoría · Forma de
/// pago" debajo y el monto a la derecha.
///
/// Sin punto de color: las categorías ya no tienen color propio (ADR-0044).
/// Solo recibe primitivos; quien la usa formatea el monto y arma el
/// subtítulo. Los ingresos llevan `+` y `positive` — el signo va aquí para
/// que el color nunca sea el único portador de información.
public struct MovementRow: View {
    @Environment(\.lana) private var lana

    private let title: String
    private let subtitle: String
    private let amountText: String
    private let secondaryAmountText: String?
    private let isIncome: Bool
    private let isSubtitleMuted: Bool
    private let needsReview: Bool
    private let isShared: Bool

    /// - Parameters:
    ///   - subtitle: "Despensa · Crédito Nu", o "Tarjeta eliminada".
    ///   - amountText: el monto ya formateado, sin signo.
    ///   - secondaryAmountText: una segunda línea bajo el monto ("de $9,000"
    ///     cuando solo se muestra la parte propia de un gasto compartido).
    ///   - isSubtitleMuted: el subtítulo en `ink35` — para "Tarjeta eliminada".
    public init(
        title: String,
        subtitle: String,
        amountText: String,
        secondaryAmountText: String? = nil,
        isIncome: Bool = false,
        isSubtitleMuted: Bool = false,
        needsReview: Bool = false,
        isShared: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.amountText = amountText
        self.secondaryAmountText = secondaryAmountText
        self.isIncome = isIncome
        self.isSubtitleMuted = isSubtitleMuted
        self.needsReview = needsReview
        self.isShared = isShared
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Space.p12.rawValue) {
            VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                Text(title)
                    .lanaFont(.rowTitle)
                    .foregroundStyle(lana.ink)
                    .lineLimit(1)
                HStack(spacing: Space.xs.rawValue) {
                    if needsReview {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(lana.attention)
                            .accessibilityLabel("Por revisar")
                    }
                    if isShared {
                        Image(systemName: "person.2")
                            .foregroundStyle(lana.ink42)
                            .accessibilityLabel("Gasto compartido")
                    }
                    Text(subtitle)
                        .foregroundStyle(isSubtitleMuted ? lana.ink35 : lana.ink42)
                        .lineLimit(1)
                }
                .lanaFont(.rowSubtitle)
            }

            Spacer(minLength: Space.sm.rawValue)

            VStack(alignment: .trailing, spacing: Space.p2.rawValue) {
                Text(isIncome ? "+\(amountText)" : amountText)
                    .lanaFont(.rowAmount)
                    .fontWeight(isIncome ? .semibold : .medium)
                    .foregroundStyle(isIncome ? lana.positive : lana.ink)
                if let secondaryAmountText {
                    Text(secondaryAmountText)
                        .lanaFont(.rowSubtitle)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink42)
                }
            }
        }
        .padding(.vertical, Space.p13.rawValue)
        .frame(minHeight: LanaMetrics.minRowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Una línea de 1 pt entre filas. `strong` para listas sobre el fondo,
/// normal dentro de una tarjeta.
public struct HairlineDivider: View {
    @Environment(\.lana) private var lana
    private let isStrong: Bool

    public init(strong: Bool = false) {
        isStrong = strong
    }

    public var body: some View {
        Rectangle()
            .fill(isStrong ? lana.hairlineStrong : lana.hairline)
            .frame(height: LanaMetrics.hairline)
            .accessibilityHidden(true)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.lg.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                VStack(spacing: 0) {
                    MovementRow(title: "Súper", subtitle: "Despensa · Crédito Nu", amountText: "$300.00")
                    HairlineDivider()
                    MovementRow(
                        title: "Quincena",
                        subtitle: "Ingreso · quincena",
                        amountText: "$6,000.00",
                        isIncome: true)
                    HairlineDivider()
                    MovementRow(
                        title: "Gasolina",
                        subtitle: "Tarjeta eliminada",
                        amountText: "$250.00",
                        isSubtitleMuted: true,
                        needsReview: true)
                    HairlineDivider()
                    MovementRow(
                        title: "Renta",
                        subtitle: "Hogar · Transferencia",
                        amountText: "$4,500.00",
                        secondaryAmountText: "de $9,000.00",
                        isShared: true)
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                .lanaTheme(theme)
            }
        }
    }
}

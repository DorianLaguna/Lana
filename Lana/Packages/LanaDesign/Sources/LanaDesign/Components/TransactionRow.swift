import SwiftUI

/// Una fila de gasto o ingreso — la unidad visual más repetida de la app
/// (bandeja de revisión, dashboard, lista de una categoría). Solo recibe
/// primitivos: `LanaDesign` no conoce el dominio, la vista que la usa
/// decide cómo formatear el monto y de dónde sale `categoryColor` (un tono
/// de `LanaColors.categoryRamp`).
public struct TransactionRow: View {
    @Environment(\.lana) private var lana

    private let concept: String
    private let categoryName: String
    private let categoryColor: Color
    private let amountText: String
    /// Una segunda línea bajo el monto, más chica y en tono secundario.
    /// `LanaDesign` no sabe qué significa: la usa el Dashboard para decir
    /// de cuánto era el gasto completo cuando solo se muestra la parte de
    /// quien mira (ADR-0029), pero es un slot genérico.
    private let secondaryAmountText: String?
    private let isIncome: Bool
    private let needsReview: Bool
    private let isShared: Bool

    public init(
        concept: String,
        categoryName: String,
        categoryColor: Color,
        amountText: String,
        secondaryAmountText: String? = nil,
        isIncome: Bool = false,
        needsReview: Bool = false,
        isShared: Bool = false) {
        self.concept = concept
        self.categoryName = categoryName
        self.categoryColor = categoryColor
        self.amountText = amountText
        self.secondaryAmountText = secondaryAmountText
        self.isIncome = isIncome
        self.needsReview = needsReview
        self.isShared = isShared
    }

    public var body: some View {
        HStack(spacing: Space.sm.rawValue) {
            Circle()
                .fill(categoryColor)
                .frame(width: Space.sm.rawValue, height: Space.sm.rawValue)

            VStack(alignment: .leading, spacing: 2) {
                Text(concept)
                    .lanaFont(.body)
                    .foregroundStyle(lana.ink)
                Text(categoryName)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.ink50)
            }

            Spacer(minLength: Space.sm.rawValue)

            if isShared {
                // Nunca el único indicador de "esto es distinto" — el monto
                // ya viene ajustado a la parte de quien mira (la vista que
                // llama a esto decide eso, `LanaDesign` no conoce de splits);
                // este ícono solo explica por qué.
                Image(systemName: "person.2")
                    .foregroundStyle(lana.ink50)
                    .accessibilityLabel("Gasto compartido")
            }

            if needsReview {
                // El color nunca es el único portador de información — el
                // ícono lleva el significado, no el tono de fondo.
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(lana.attention)
                    .accessibilityLabel("Necesita revisión")
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .lanaFont(.body)
                    .monospacedDigit()
                    .foregroundStyle(isIncome ? lana.positive : lana.ink)
                if let secondaryAmountText {
                    Text(secondaryAmountText)
                        .lanaFont(.caption)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink50)
                }
            }
        }
        .padding(.vertical, Space.xs.rawValue)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    VStack(spacing: Space.sm.rawValue) {
                        TransactionRow(
                            concept: "Café con Ana",
                            categoryName: "Comida",
                            categoryColor: LanaColors(theme: theme, colorScheme: .light).categoryRamp[0],
                            amountText: "$131.00")
                        TransactionRow(
                            concept: "Nómina",
                            categoryName: "Ingreso",
                            categoryColor: LanaColors(theme: theme, colorScheme: .light).categoryRamp[1],
                            amountText: "$5,000.00",
                            isIncome: true)
                        TransactionRow(
                            concept: "Gasolina",
                            categoryName: "Transporte",
                            categoryColor: LanaColors(theme: theme, colorScheme: .light).categoryRamp[2],
                            amountText: "$1,010.00",
                            needsReview: true)
                        TransactionRow(
                            concept: "Renta",
                            categoryName: "Hogar",
                            categoryColor: LanaColors(theme: theme, colorScheme: .light).categoryRamp[3],
                            amountText: "$4,500.00",
                            secondaryAmountText: "de $9,000.00",
                            isShared: true)
                    }
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

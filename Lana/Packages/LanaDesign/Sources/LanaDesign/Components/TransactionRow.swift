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
    private let isIncome: Bool
    private let needsReview: Bool

    public init(
        concept: String,
        categoryName: String,
        categoryColor: Color,
        amountText: String,
        isIncome: Bool = false,
        needsReview: Bool = false) {
        self.concept = concept
        self.categoryName = categoryName
        self.categoryColor = categoryColor
        self.amountText = amountText
        self.isIncome = isIncome
        self.needsReview = needsReview
    }

    public var body: some View {
        HStack(spacing: Space.sm.rawValue) {
            Circle()
                .fill(categoryColor)
                .frame(width: Space.sm.rawValue, height: Space.sm.rawValue)

            VStack(alignment: .leading, spacing: 2) {
                Text(concept)
                    .lanaFont(.body)
                    .foregroundStyle(lana.textPrimary)
                Text(categoryName)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.textSecondary)
            }

            Spacer(minLength: Space.sm.rawValue)

            if needsReview {
                // El color nunca es el único portador de información — el
                // ícono lleva el significado, no el tono de fondo.
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(lana.warning)
                    .accessibilityLabel("Necesita revisión")
            }

            Text(amountText)
                .lanaFont(.body)
                .monospacedDigit()
                .foregroundStyle(isIncome ? lana.positive : lana.textPrimary)
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
                    }
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

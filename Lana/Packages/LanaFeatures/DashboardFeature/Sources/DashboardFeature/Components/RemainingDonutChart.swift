import LanaCore
import LanaDesign
import SwiftUI

/// Qué tanto del ingreso del mes ya se fue en cada categoría, y cuánto
/// sobra — una dona en vez de barras porque aquí lo que importa es la
/// proporción contra el total (el ingreso), no comparar categorías entre sí
/// (eso ya lo hace `CategoryBreakdownChart`). Dibujada a mano, mismo motivo
/// documentado ahí: nada aquí necesita ser tocable, pero sí necesita un
/// denominador propio (el ingreso, no la suma de categorías) que `Charts`
/// no da gratis sin escribir el mismo cálculo de todos modos.
public struct RemainingDonutChart: View {
    @Environment(\.lana) private var lana

    private let categoryTotals: [CategoryTotal]
    private let income: Decimal
    private let currency: Currency

    public init(categoryTotals: [CategoryTotal], income: Decimal, currency: Currency) {
        self.categoryTotals = categoryTotals
        self.income = income
        self.currency = currency
    }

    private var expenses: Decimal {
        categoryTotals.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Decimal {
        max(0, income - expenses)
    }

    /// El mayor entre ingreso y gasto — si te sobregiraste, el círculo se
    /// llena de categorías sin un cacho de "disponible" (no hay nada que
    /// sobre), en vez de que las categorías se salgan del trazo.
    private var total: Decimal {
        max(income, expenses)
    }

    private var isOverIncome: Bool {
        expenses > income
    }

    public var body: some View {
        VStack(spacing: Space.md.rawValue) {
            ZStack {
                Circle()
                    .stroke(lana.hairlineStrong, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                centerLabel
            }
            .frame(width: 168, height: 168)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)

            legend
        }
    }

    private struct Segment {
        let start: Double
        let end: Double
        let color: Color
    }

    private var segments: [Segment] {
        guard total > 0 else { return [] }
        var cursor = 0.0
        var result: [Segment] = []
        for categoryTotal in categoryTotals {
            let fraction = Double(truncating: (categoryTotal.amount / total) as NSDecimalNumber)
            result.append(Segment(start: cursor, end: cursor + fraction, color: color(for: categoryTotal.category)))
            cursor += fraction
        }
        if remaining > 0 {
            let fraction = Double(truncating: (remaining / total) as NSDecimalNumber)
            result.append(Segment(start: cursor, end: cursor + fraction, color: lana.positive))
        }
        return result
    }

    private var centerLabel: some View {
        VStack(spacing: 2) {
            if isOverIncome {
                // Un dato con su cifra al lado, no un reproche (Docs/CLAUDE.md → Tono).
                Text("Sin margen")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.ink50)
                Text(Money(amount: expenses - income, currency: currency).formatted())
                    .lanaFont(.headline)
                    .monospacedDigit()
                    .foregroundStyle(lana.attention)
            } else {
                Text("Te sobra")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.ink50)
                Text(Money(amount: remaining, currency: currency).formatted())
                    .lanaFont(.headline)
                    .monospacedDigit()
                    .foregroundStyle(lana.positive)
            }
        }
        .multilineTextAlignment(.center)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
            ForEach(categoryTotals) { total in
                legendRow(
                    color: color(for: total.category),
                    label: total.category.capitalized,
                    amount: Money(amount: total.amount, currency: total.currency).formatted())
            }
            if remaining > 0 {
                legendRow(
                    color: lana.positive,
                    label: "Disponible",
                    amount: Money(amount: remaining, currency: currency).formatted())
            }
        }
    }

    private func legendRow(color: Color, label: String, amount: String) -> some View {
        HStack(spacing: Space.xs.rawValue) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .lanaFont(.caption)
                .foregroundStyle(lana.ink50)
            Spacer()
            Text(amount)
                .lanaFont(.caption)
                .monospacedDigit()
                .foregroundStyle(lana.ink50)
        }
    }

    private var accessibilityLabel: String {
        let remainingText = Money(amount: remaining, currency: currency).formatted()
        let incomeText = Money(amount: income, currency: currency).formatted()
        if isOverIncome {
            let overText = Money(amount: expenses - income, currency: currency).formatted()
            return "Sin margen, \(overText) arriba de tu ingreso"
        }
        return "Te sobra \(remainingText) de \(incomeText)"
    }

    private func color(for category: String) -> Color {
        lana.categoryRamp[category.lowercased().stableRampIndex]
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    RemainingDonutChart(
                        categoryTotals: [
                            CategoryTotal(category: "despensa", amount: 2500, currency: .mxn),
                            CategoryTotal(category: "transporte", amount: 1200, currency: .mxn),
                            CategoryTotal(category: "comida", amount: 900, currency: .mxn)
                        ],
                        income: 15000,
                        currency: .mxn)
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

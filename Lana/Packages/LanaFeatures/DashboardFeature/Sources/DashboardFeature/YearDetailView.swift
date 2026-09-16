import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// "Más detalle" del año (rediseño, sección 09): subcategorías, formas de
/// pago, gastos hormiga y rachas.
///
/// Antes era un acordeón dentro de El año y alargaba esa pantalla sin
/// necesidad. Como push, quien no lo necesita no lo ve.
struct YearDetailView: View {
    @Environment(\.lana) private var lana
    let statistics: AnnualStatistics
    let currency: Currency

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                block("En qué específicamente", rows: subcategoryRows)
                block("Por forma de pago", rows: paymentRows)
                block("Chico pero seguido", rows: antRows)
                block("Días con movimiento", rows: consistencyRows)
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance()
        }
        .background(lana.bg)
        .navigationTitle("Más detalle")
        .lanaInlineNavigationTitle()
    }

    private struct DetailRow: Identifiable {
        let id: String
        let label: String
        let value: String
    }

    @ViewBuilder
    private func block(_ title: String, rows: [DetailRow]) -> some View {
        if !rows.isEmpty {
            SectionHeader(title)
                .padding(.bottom, Space.p12.rawValue)
            LanaCard(padding: nil) {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: Space.p10.rawValue) {
                            Text(row.label)
                                .lanaFont(.bodyEmphasis)
                                .fontWeight(.regular)
                                .foregroundStyle(lana.ink)
                            Spacer(minLength: Space.sm.rawValue)
                            Text(row.value)
                                .lanaFont(.rowTitle)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(lana.ink)
                        }
                        .padding(Space.md.rawValue)
                        .accessibilityElement(children: .combine)
                        if index < rows.count - 1 {
                            HairlineDivider()
                        }
                    }
                }
            }
            .padding(.bottom, Space.p28.rawValue)
        }
    }

    private var subcategoryRows: [DetailRow] {
        statistics.period.subcategoryTotals(in: currency).prefix(8).map { total in
            DetailRow(
                id: "sub-\(total.category)",
                label: total.category.prefix(1).uppercased() + total.category.dropFirst(),
                value: Money(amount: total.amount, currency: total.currency).formatted())
        }
    }

    private var paymentRows: [DetailRow] {
        statistics.period.paymentMethodTotals(in: currency).map { total in
            DetailRow(
                id: "pago-\(total.category)",
                label: total.category.prefix(1).uppercased() + total.category.dropFirst(),
                value: Money(amount: total.amount, currency: total.currency).formatted())
        }
    }

    /// Lo chico que se repite: el conteo viaja en la etiqueta porque es la
    /// mitad del dato.
    private var antRows: [DetailRow] {
        statistics.antExpenses(in: currency).map { group in
            DetailRow(
                id: "hormiga-\(group.label)",
                label: "\(group.label.prefix(1).uppercased() + group.label.dropFirst()) · \(group.count) veces",
                value: Money(amount: group.total, currency: group.currency).formatted())
        }
    }

    /// "Días con movimiento", no "racha de captura": el dato sale de la fecha
    /// del gasto, no de cuándo se registró.
    private var consistencyRows: [DetailRow] {
        let consistency = statistics.captureConsistency
        guard consistency.daysWithActivity > 0 else { return [] }
        var rows = [
            DetailRow(
                id: "dias",
                label: "Días registrados",
                value: "\(consistency.daysWithActivity) de \(consistency.daysElapsed)"),
            DetailRow(id: "racha-larga", label: "Racha más larga", value: "\(consistency.longestStreak) días")
        ]
        if consistency.currentStreak > 0 {
            rows.append(DetailRow(
                id: "racha-actual",
                label: "Racha actual",
                value: "\(consistency.currentStreak) días"))
        }
        return rows
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            YearDetailView(
                statistics: AnnualStatistics(year: 2026, expenses: []),
                currency: .mxn)
        }
        .lanaTheme(theme)
    }
}

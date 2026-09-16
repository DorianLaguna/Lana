import LanaCore
import LanaDesign
import SwiftUI

/// El "por qué" detrás de una fila de `BalancesView`: gasto por gasto, cómo
/// se dividió y cuánto le tocó a cada quien, con la suma llegando a la
/// misma cifra que ya se veía (ADR-0024). Con exactamente dos participantes
/// en la lista, ambas cifras siempre coinciden; con 3+, esto es la relación
/// directa entre estos dos, que puede diferir de la deuda ya simplificada
/// si un tercer participante quedó de por medio (ver doc comment de
/// `PersonLedger.contributions(between:and:in:)`).
public struct DebtDetailView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    private let debt: Debt
    private let contributions: [DebtContribution]
    private let participantName: (ParticipantID) -> String

    public init(debt: Debt, contributions: [DebtContribution], participantName: @escaping (ParticipantID) -> String) {
        self.debt = debt
        self.contributions = contributions
        self.participantName = participantName
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    total
                        .padding(.bottom, Space.p22.rawValue)

                    if contributions.isEmpty {
                        Text("No hay gastos directos entre \(fromName) y \(toName) todavía.")
                            .lanaFont(.explanation)
                            .foregroundStyle(lana.ink50)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        SectionHeader("De dónde sale")
                            .padding(.bottom, Space.p10.rawValue)
                        LanaCard {
                            VStack(spacing: 0) {
                                ForEach(
                                    Array(runningTotals.enumerated()),
                                    id: \.element.contribution.id) { index, entry in
                                        contributionRow(entry.contribution, runningTotal: entry.runningTotal)
                                        if index != runningTotals.count - 1 {
                                            HairlineDivider()
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.p18.rawValue)
                .padding(.bottom, Space.p40.rawValue)
            }
            .background(lana.bg)
            .navigationTitle("Detalle del saldo")
            .lanaInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var total: some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            Text("\(fromName) le debe a \(toName)")
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)
            Text(debt.amount.formatted())
                .lanaFont(.blockAmount)
                .foregroundStyle(lana.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private var fromName: String {
        participantName(debt.from)
    }

    private var toName: String {
        participantName(debt.to)
    }

    /// El acumulado corre en el mismo orden cronológico que `contributions`
    /// (ya viene ordenado por fecha) — así la última fila muestra
    /// exactamente el saldo vigente, la misma cifra de la tarjeta de arriba.
    private var runningTotals: [(contribution: DebtContribution, runningTotal: Decimal)] {
        var total = Decimal(0)
        return contributions.map { contribution in
            total += contribution.signedEffect
            return (contribution, total)
        }
    }

    private func contributionRow(_ contribution: DebtContribution, runningTotal: Decimal) -> some View {
        let payerLine = "\(LanaDateFormat.shortDate(contribution.date)) · " +
            "pagó \(participantName(contribution.payer))"
        let sharesLine = "\(fromName): \(contribution.fromShare.formatted()) · " +
            "\(toName): \(contribution.toShare.formatted())"
        let runningTotalMoney = Money(amount: abs(runningTotal), currency: contribution.amount.currency)

        return VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            HStack(spacing: Space.p12.rawValue) {
                VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                    Text(contribution.concept)
                        .lanaFont(.rowTitle)
                        .foregroundStyle(lana.ink)
                    Text(payerLine)
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink50)
                }
                Spacer(minLength: Space.sm.rawValue)
                Text(contribution.amount.formatted())
                    .lanaFont(.rowAmount)
                    .foregroundStyle(lana.ink)
            }
            HStack(spacing: Space.sm.rawValue) {
                Text(sharesLine)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                Spacer(minLength: Space.xs.rawValue)
                Text("acumulado \(runningTotalMoney.formatted())")
                    .lanaFont(.rowSubtitle)
                    .monospacedDigit()
                    .foregroundStyle(lana.ink42)
            }
        }
        .padding(.vertical, Space.p10.rawValue)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let alice = Participant(displayName: "Tú")
    let bob = Participant(displayName: "Sam")
    let debt = Debt(from: bob.id, to: alice.id, amount: Money(amount: 30, currency: .mxn))
    let contributions = [
        DebtContribution(
            id: EventID(),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            concept: "Renta",
            amount: Money(amount: 100, currency: .mxn),
            payer: alice.id,
            fromShare: Money(amount: 50, currency: .mxn),
            toShare: Money(amount: 50, currency: .mxn),
            signedEffect: 50),
        DebtContribution(
            id: EventID(),
            date: Date(timeIntervalSince1970: 1_700_100_000),
            concept: "Internet",
            amount: Money(amount: 40, currency: .mxn),
            payer: bob.id,
            fromShare: Money(amount: 20, currency: .mxn),
            toShare: Money(amount: 20, currency: .mxn),
            signedEffect: -20)
    ]
    ForEach(LanaTheme.allCases) { theme in
        DebtDetailView(
            debt: debt,
            contributions: contributions,
            participantName: { $0 == alice.id ? alice.displayName : bob.displayName })
            .lanaTheme(theme)
    }
}

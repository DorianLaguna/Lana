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
                VStack(alignment: .leading, spacing: Space.md.rawValue) {
                    LanaCard {
                        HStack {
                            Text("\(fromName) le debe a \(toName)")
                                .lanaFont(.body)
                                .foregroundStyle(lana.ink)
                            Spacer()
                            Text(debt.amount.formatted())
                                .lanaFont(.title)
                                .monospacedDigit()
                                .foregroundStyle(lana.ink)
                        }
                    }

                    if contributions.isEmpty {
                        Text("No hay gastos directos entre \(fromName) y \(toName) todavía.")
                            .lanaFont(.body)
                            .foregroundStyle(lana.ink50)
                    } else {
                        LanaCard {
                            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                                Text("De dónde sale")
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.ink50)
                                VStack(spacing: 0) {
                                    ForEach(
                                        Array(runningTotals.enumerated()),
                                        id: \.element.contribution.id) { index, entry in
                                            contributionRow(entry.contribution, runningTotal: entry.runningTotal)
                                            if index != runningTotals.count - 1 {
                                                Divider()
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(Space.md.rawValue)
            }
            .background(lana.bg)
            .navigationTitle("Detalle del saldo")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { dismiss() }
                    }
                }
        }
        .presentationDragIndicator(.visible)
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
        let payerLine = "\(contribution.date.formatted(date: .abbreviated, time: .omitted)) · " +
            "pagó \(participantName(contribution.payer))"
        let sharesLine = "\(fromName): \(contribution.fromShare.formatted()) · " +
            "\(toName): \(contribution.toShare.formatted())"
        let runningTotalMoney = Money(amount: abs(runningTotal), currency: contribution.amount.currency)

        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contribution.concept)
                        .lanaFont(.body)
                        .foregroundStyle(lana.ink)
                    Text(payerLine)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.ink50)
                }
                Spacer()
                Text(contribution.amount.formatted())
                    .lanaFont(.body)
                    .monospacedDigit()
                    .foregroundStyle(lana.ink)
            }
            HStack(spacing: Space.sm.rawValue) {
                Text(sharesLine)
                    .lanaFont(.caption)
                    .foregroundStyle(lana.ink50)
                Spacer()
                Text("acumulado \(runningTotalMoney.formatted())")
                    .lanaFont(.caption)
                    .monospacedDigit()
                    .foregroundStyle(lana.ink50)
            }
        }
        .padding(.vertical, Space.xs.rawValue)
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

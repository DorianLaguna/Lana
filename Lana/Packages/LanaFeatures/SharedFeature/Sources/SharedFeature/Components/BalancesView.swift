import LanaCore
import LanaDesign
import SwiftUI

/// Los saldos de una lista compartida: cuánto le debe o le deben a cada
/// quien, con tendencia — no solo el número puntual (ADR-0008). Sin tono de
/// reclamo: deber no se pinta de alerta, es un hecho (ADR-0044).
public struct BalancesView: View {
    @Environment(\.lana) private var lana
    private let balances: [ParticipantBalance]
    private let debts: [Debt]
    private let participantName: (ParticipantID) -> String
    private let onSettle: (Debt) -> Void
    private let onSelectDebt: (Debt) -> Void

    public init(
        balances: [ParticipantBalance],
        debts: [Debt],
        participantName: @escaping (ParticipantID) -> String,
        onSettle: @escaping (Debt) -> Void,
        onSelectDebt: @escaping (Debt) -> Void) {
        self.balances = balances
        self.debts = debts
        self.participantName = participantName
        self.onSettle = onSettle
        self.onSelectDebt = onSelectDebt
    }

    public var body: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                Text("Saldos")
                    .lanaFont(.minorHeader)
                    .foregroundStyle(lana.ink42)
                    .accessibilityAddTraits(.isHeader)

                if balances.isEmpty {
                    Text("Todo saldado — nadie le debe a nadie.")
                        .lanaFont(.explanation)
                        .foregroundStyle(lana.ink50)
                } else {
                    VStack(spacing: 0) {
                        ForEach(balances) { balance in
                            balanceRow(balance)
                            if balance.id != balances.last?.id {
                                HairlineDivider()
                            }
                        }
                    }

                    if !debts.isEmpty {
                        VStack(spacing: Space.sm.rawValue) {
                            ForEach(Array(debts.enumerated()), id: \.offset) { _, debt in
                                debtRow(debt)
                            }
                        }
                    }
                }
            }
        }
    }

    private func balanceRow(_ balance: ParticipantBalance) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            Text(balance.participant.displayName)
                .lanaFont(.rowTitle)
                .foregroundStyle(lana.ink)

            trendIcon(balance.trend)

            Spacer(minLength: Space.sm.rawValue)

            Text(Money(amount: abs(balance.amount), currency: balance.currency).formatted())
                .lanaFont(.rowAmount)
                .foregroundStyle(balance.amount > 0 ? lana.positive : lana.ink)
            Text(balance.amount > 0 ? "le deben" : "debe")
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink50)
        }
        .padding(.vertical, Space.p10.rawValue)
        .accessibilityElement(children: .combine)
    }

    private func trendIcon(_ trend: ParticipantBalance.Trend) -> some View {
        let systemImage = switch trend {
        case .growing: "arrow.up.right"
        case .shrinking: "arrow.down.right"
        case .stable: "arrow.right"
        }
        let label = switch trend {
        case .growing: "va creciendo"
        case .shrinking: "va bajando"
        case .stable: "sin cambio"
        }
        return Image(systemName: systemImage)
            .lanaFont(.axisLabel)
            .fontWeight(.semibold)
            .foregroundStyle(lana.ink50)
            .accessibilityLabel(label)
    }

    /// Quién le paga a quién, ya simplificado, con la acción al lado: el
    /// renglón entero abre el detalle y "Liquidar" registra el pago.
    private func debtRow(_ debt: Debt) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            Button {
                onSelectDebt(debt)
            } label: {
                HStack(spacing: Space.sm.rawValue) {
                    Text("\(participantName(debt.from)) le debe a \(participantName(debt.to))")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink50)
                    Spacer(minLength: Space.xs.rawValue)
                    Text(debt.amount.formatted())
                        .lanaFont(.rowSubtitle)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button("Liquidar") {
                onSettle(debt)
            }
            .buttonStyle(.lana(.secondary, size: .compact))
        }
        .frame(minHeight: LanaMetrics.minTouchTarget)
    }
}

#Preview {
    let alice = Participant(displayName: "Tú")
    let bob = Participant(displayName: "Sam")
    ForEach(LanaTheme.allCases) { theme in
        BalancesView(
            balances: [
                ParticipantBalance(participant: alice, amount: 250, currency: .mxn, trend: .growing),
                ParticipantBalance(participant: bob, amount: -250, currency: .mxn, trend: .shrinking)
            ],
            debts: [Debt(from: bob.id, to: alice.id, amount: Money(amount: 250, currency: .mxn))],
            participantName: { $0 == alice.id ? alice.displayName : bob.displayName },
            onSettle: { _ in },
            onSelectDebt: { _ in })
            .padding(Space.md.rawValue)
            .lanaTheme(theme)
    }
}

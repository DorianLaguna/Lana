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
    private let viewerID: ParticipantID?
    private let onSettle: (Debt) -> Void
    private let onSelectDebt: (Debt) -> Void

    public init(
        balances: [ParticipantBalance],
        debts: [Debt],
        participantName: @escaping (ParticipantID) -> String,
        viewerID: ParticipantID? = nil,
        onSettle: @escaping (Debt) -> Void,
        onSelectDebt: @escaping (Debt) -> Void) {
        self.balances = balances
        self.debts = debts
        self.participantName = participantName
        self.viewerID = viewerID
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
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            // Los saldos dicen cuánto; esto, quién le paga a
                            // quién para quedar a mano. Sin el encabezado se
                            // leía como una segunda lista de saldos.
                            Text("Para quedar a mano")
                                .lanaFont(.minorHeader)
                                .foregroundStyle(lana.ink42)
                                .accessibilityAddTraits(.isHeader)
                                .padding(.top, Space.md.rawValue)
                            ForEach(
                                Array(orderedDebts(debts, viewer: viewerID).enumerated()),
                                id: \.offset) { _, debt in
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
            // El mismo nombre que en "Para quedar a mano": "Yo" para quien
            // mira. Con `participant.displayName` salía "Dorian" arriba y
            // "Yo" abajo, y parecían dos personas.
            Text(participantName(balance.participant.id))
                .lanaFont(.rowTitle)
                .foregroundStyle(lana.ink)

            trendIcon(balance.trend)

            Spacer(minLength: Space.sm.rawValue)

            Text(Money(amount: abs(balance.amount), currency: balance.currency).formatted())
                .lanaFont(.rowAmount)
                .foregroundStyle(balance.amount > 0 ? lana.positive : lana.ink)
            Text(balanceLabel(isOwed: balance.amount > 0, isViewer: balance.participant.id == viewerID))
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

    /// Quién le paga a quién según el plan de pagos (ADR-0053), con la acción al lado: el
    /// renglón entero abre el detalle y "Liquidar" registra el pago.
    private func debtRow(_ debt: Debt) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            Button {
                onSelectDebt(debt)
            } label: {
                HStack(spacing: Space.sm.rawValue) {
                    Text(debtPhrase(debt, viewer: viewerID, name: participantName))
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

/// "le deben" / "debe", o "te deben" / "debes" para quien mira.
func balanceLabel(isOwed: Bool, isViewer: Bool) -> String {
    switch (isOwed, isViewer) {
    case (true, true): "te deben"
    case (false, true): "debes"
    case (true, false): "le deben"
    case (false, false): "debe"
    }
}

/// "Evan te debe", "Le debes a Iori" o "Kin le debe a Iori". Antes siempre
/// era la tercera forma, y daba "Evan le debe a Yo".
func debtPhrase(_ debt: Debt, viewer: ParticipantID?, name: (ParticipantID) -> String) -> String {
    if debt.to == viewer {
        return "\(name(debt.from)) te debe"
    }
    if debt.from == viewer {
        return "Le debes a \(name(debt.to))"
    }
    return "\(name(debt.from)) le debe a \(name(debt.to))"
}

/// Lo que toca a quien mira va primero —lo que le deben, luego lo que debe—
/// y después lo de los demás, cada grupo de mayor a menor. Antes salían en el
/// orden en que salían del cálculo.
func orderedDebts(_ debts: [Debt], viewer: ParticipantID?) -> [Debt] {
    func group(_ debt: Debt) -> Int {
        if debt.to == viewer {
            return 0
        }
        if debt.from == viewer {
            return 1
        }
        return 2
    }
    return debts.enumerated().sorted { lhs, rhs in
        let (left, right) = (lhs.element, rhs.element)
        if group(left) != group(right) {
            return group(left) < group(right)
        }
        if left.amount.amount != right.amount.amount {
            return left.amount.amount > right.amount.amount
        }
        return lhs.offset < rhs.offset
    }
    .map(\.element)
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

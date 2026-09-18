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

                    settlements
                }
            }
        }
    }

    /// Solo lo que te toca a ti: quién te debe y a quién le debes. Lo que se
    /// deban entre ellos no se muestra — lo que se necesita saber es quién ya
    /// te pagó, no llevarle la cuenta a los demás.
    @ViewBuilder
    private var settlements: some View {
        let mine = myDebts(debts, viewer: viewerID)
        if !mine.owedToMe.isEmpty || !mine.iOwe.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                if !mine.owedToMe.isEmpty {
                    settlementSection("Te deben", debts: mine.owedToMe, paidLabel: "Ya me pagó") { $0.from }
                }
                if !mine.iOwe.isEmpty {
                    settlementSection("Tú debes", debts: mine.iOwe, paidLabel: "Ya pagué") { $0.to }
                }
            }
        }
    }

    private func settlementSection(
        _ title: String,
        debts: [Debt],
        paidLabel: String,
        other: @escaping (Debt) -> ParticipantID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .lanaFont(.minorHeader)
                .foregroundStyle(lana.ink42)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Space.md.rawValue)
                .padding(.bottom, Space.xs.rawValue)
            ForEach(debts, id: \.self) { debt in
                debtRow(debt, name: participantName(other(debt)), paidLabel: paidLabel)
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

    private func debtRow(_ debt: Debt, name: String, paidLabel: String) -> some View {
        HStack(spacing: Space.sm.rawValue) {
            Button {
                onSelectDebt(debt)
            } label: {
                HStack(spacing: Space.sm.rawValue) {
                    Text(name)
                        .lanaFont(.label)
                        .foregroundStyle(lana.ink70)
                    Spacer(minLength: Space.xs.rawValue)
                    Text(debt.amount.formatted())
                        .lanaFont(.label)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(debtPhrase(debt, viewer: viewerID, name: participantName)) \(debt.amount.formatted())")
            .accessibilityHint("Ver de dónde sale")

            Button {
                onSettle(debt)
            } label: {
                // Mismo ancho en los dos bloques, para que los montos queden
                // alineados entre "Te deben" y "Tú debes".
                ZStack {
                    Text("Ya me pagó").hidden()
                    Text(paidLabel)
                }
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

/// Las deudas que te tocan a ti, separadas por lado y de mayor a menor. Las
/// de terceros entre sí se quedan fuera (ADR-0053 las calcula igual: solo no
/// se muestran).
func myDebts(_ debts: [Debt], viewer: ParticipantID?) -> (owedToMe: [Debt], iOwe: [Debt]) {
    func sorted(_ debts: [Debt]) -> [Debt] {
        debts.sorted { $0.amount.amount > $1.amount.amount }
    }
    guard let viewer else { return ([], []) }
    return (
        owedToMe: sorted(debts.filter { $0.to == viewer }),
        iOwe: sorted(debts.filter { $0.from == viewer }))
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

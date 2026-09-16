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
                            ForEach(debtGroups(debts, viewer: viewerID)) { group in
                                debtGroup(group)
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

    /// Una persona que debe, con su total, y debajo a quién le paga y cuánto
    /// (ADR-0053). Cada fila abre el detalle; "Ya pagó" registra el pago.
    private func debtGroup(_ group: DebtGroup) -> some View {
        let isViewer = group.debtor == viewerID
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm.rawValue) {
                Text(isViewer ? "Tú debes" : "\(participantName(group.debtor)) debe")
                    .lanaFont(.rowTitle)
                    .foregroundStyle(lana.ink)
                Spacer(minLength: Space.sm.rawValue)
                Text(group.total.formatted())
                    .lanaFont(.rowAmount)
                    .foregroundStyle(lana.ink)
            }
            .padding(.bottom, Space.xs.rawValue)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(group.debts, id: \.to) { debt in
                debtRow(debt, debtorIsViewer: isViewer)
            }
        }
        .padding(.vertical, Space.p10.rawValue)
    }

    private func debtRow(_ debt: Debt, debtorIsViewer: Bool) -> some View {
        let creditorIsViewer = debt.to == viewerID
        let creditor = creditorIsViewer ? "ti" : participantName(debt.to)
        let paidLabel = debtorIsViewer ? "Ya pagué" : (creditorIsViewer ? "Ya me pagó" : "Ya pagó")
        return HStack(spacing: Space.sm.rawValue) {
            Button {
                onSelectDebt(debt)
            } label: {
                HStack(spacing: Space.sm.rawValue) {
                    Text("a \(creditor)")
                        .lanaFont(.label)
                        .foregroundStyle(lana.ink70)
                    Spacer(minLength: Space.xs.rawValue)
                    Text(debt.amount.formatted())
                        .lanaFont(.label)
                        .monospacedDigit()
                        .foregroundStyle(lana.ink)
                }
                .padding(.leading, Space.md.rawValue)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(debtPhrase(debt, viewer: viewerID, name: participantName)) \(debt.amount.formatted())")
            .accessibilityHint("Ver de dónde sale")

            Button {
                onSettle(debt)
            } label: {
                // Mismo ancho para las tres etiquetas, para que los montos
                // queden alineados de grupo en grupo.
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

/// Las deudas de una persona, juntas: "Bruno debe $122.21 — a Iori $66.83,
/// a Liz $55.38".
struct DebtGroup: Identifiable {
    let debtor: ParticipantID
    let debts: [Debt]

    var id: ParticipantID {
        debtor
    }

    var total: Money {
        let currency = debts.first?.amount.currency ?? .mxn
        return Money(amount: debts.reduce(Decimal(0)) { $0 + $1.amount.amount }, currency: currency)
    }
}

/// Agrupa por quien debe. Primero quien mira, si debe; luego los demás de
/// mayor a menor. Dentro de cada grupo, primero lo que te pagan a ti y luego
/// de mayor a menor.
func debtGroups(_ debts: [Debt], viewer: ParticipantID?) -> [DebtGroup] {
    Dictionary(grouping: debts, by: \.from)
        .map { debtor, owed in
            DebtGroup(debtor: debtor, debts: owed.sorted { lhs, rhs in
                if (lhs.to == viewer) != (rhs.to == viewer) {
                    return lhs.to == viewer
                }
                return lhs.amount.amount == rhs.amount.amount ? lhs.to < rhs.to : lhs.amount.amount > rhs.amount.amount
            })
        }
        .sorted { lhs, rhs in
            if (lhs.debtor == viewer) != (rhs.debtor == viewer) {
                return lhs.debtor == viewer
            }
            let (left, right) = (lhs.total.amount, rhs.total.amount)
            return left == right ? lhs.debtor < rhs.debtor : left > right
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

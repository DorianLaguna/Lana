import LanaCore
import LanaDesign
import SwiftUI

/// De dónde sale una fila de "Para quedar a mano" (ADR-0053).
public struct DebtExplanation: Sendable {
    public let debt: Debt
    /// Todo lo que debe quien paga, en la lista entera.
    public let debtorOwes: Money
    /// Todo lo que cobra quien recibe.
    public let creditorCollects: Money
    /// Lo que se debe en la lista, sumando a todos los que cobran.
    public let totalOwed: Money
    /// Los movimientos que formaron el saldo de quien debe.
    public let debtorEntries: [BalanceEntry]

    public init(
        debt: Debt,
        debtorOwes: Money,
        creditorCollects: Money,
        totalOwed: Money,
        debtorEntries: [BalanceEntry]) {
        self.debt = debt
        self.debtorOwes = debtorOwes
        self.creditorCollects = creditorCollects
        self.totalOwed = totalOwed
        self.debtorEntries = debtorEntries
    }

    /// Qué parte de lo que se debe en la lista cobra quien recibe, en 0...100.
    public var creditorPercent: Int {
        Percentage.rounded(creditorCollects.amount, of: totalOwed.amount)
    }
}

/// El "por qué" detrás de una fila de `BalancesView`. Antes mostraba los
/// gastos entre las dos personas (ADR-0024), pero las filas ya no son
/// deudas de un par: son el saldo de quien debe repartido entre quienes
/// cobran. Así que explica eso, y abajo muestra cómo se formó ese saldo.
public struct DebtDetailView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    private let explanation: DebtExplanation
    private let viewerID: ParticipantID?
    private let participantName: (ParticipantID) -> String

    public init(
        explanation: DebtExplanation,
        viewerID: ParticipantID?,
        participantName: @escaping (ParticipantID) -> String) {
        self.explanation = explanation
        self.viewerID = viewerID
        self.participantName = participantName
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    total
                        .padding(.bottom, Space.p22.rawValue)

                    SectionHeader("Cómo sale")
                        .padding(.bottom, Space.p10.rawValue)
                    LanaCard {
                        Text(howItIsComputed)
                            .lanaFont(.explanation)
                            .foregroundStyle(lana.ink70)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, Space.p26.rawValue)

                    if !explanation.debtorEntries.isEmpty {
                        SectionHeader(isViewer(debt.from) ? "Tu saldo" : "El saldo de \(fromName)")
                            .padding(.bottom, Space.p10.rawValue)
                        LanaCard {
                            VStack(spacing: 0) {
                                ForEach(
                                    Array(explanation.debtorEntries.enumerated()),
                                    id: \.element.id) { index, entry in
                                        entryRow(entry)
                                        HairlineDivider()
                                            .opacity(index == explanation.debtorEntries.count - 1 ? 0 : 1)
                                    }
                                balanceTotalRow
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

    private var debt: Debt {
        explanation.debt
    }

    private var total: some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            Text(debtPhrase(debt, viewer: viewerID, name: participantName))
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)
            Text(debt.amount.formatted())
                .lanaFont(.blockAmount)
                .foregroundStyle(lana.ink)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Debes $21.21 en total. Iori cobra $345.77 de los $632.27 que se deben
    /// en la lista, el 55 %, así que le toca esa parte de lo tuyo: $11.60."
    private var howItIsComputed: String {
        let owes = isViewer(debt.from)
            ? "Debes \(explanation.debtorOwes.formatted()) en total en la lista."
            : "\(fromName) debe \(explanation.debtorOwes.formatted()) en total en la lista."
        let collects = isViewer(debt.to)
            ? "Tú cobras"
            : "\(toName) cobra"
        let yours = isViewer(debt.from) ? "de lo tuyo" : "de lo suyo"
        let receiver = isViewer(debt.to) ? "te toca" : "le toca"
        return """
        \(owes) \(collects) \(explanation.creditorCollects.formatted()) de los \
        \(explanation.totalOwed.formatted()) que se deben, el \(explanation.creditorPercent) %, \
        así que \(receiver) esa parte \(yours): \(debt.amount.formatted()).
        """
    }

    private func entryRow(_ entry: BalanceEntry) -> some View {
        let detail = entry.isSettlement
            ? LanaDateFormat.shortDate(entry.date)
            : "\(LanaDateFormat.shortDate(entry.date)) · pagó \(participantName(entry.payer)) · " +
            "le tocó \(entry.share.formatted())"
        let effect = Money(amount: abs(entry.effect), currency: entry.amount.currency).formatted()
        return HStack(alignment: .firstTextBaseline, spacing: Space.p12.rawValue) {
            VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                Text(entry.concept)
                    .lanaFont(.rowTitle)
                    .foregroundStyle(lana.ink)
                Text(detail)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Space.sm.rawValue)
            // + le deben más; − debe más. El signo va escrito: el color no
            // es el único portador de información.
            Text(entry.effect >= 0 ? "+\(effect)" : "−\(effect)")
                .lanaFont(.rowAmount)
                .foregroundStyle(entry.effect >= 0 ? lana.positive : lana.ink)
        }
        .padding(.vertical, Space.p10.rawValue)
        .accessibilityElement(children: .combine)
    }

    private var balanceTotalRow: some View {
        HStack {
            Text(isViewer(debt.from) ? "Debes" : "Debe")
                .lanaFont(.rowTitle)
                .foregroundStyle(lana.ink)
            Spacer(minLength: Space.sm.rawValue)
            Text(explanation.debtorOwes.formatted())
                .lanaFont(.rowAmountStrong)
                .foregroundStyle(lana.ink)
        }
        .padding(.top, Space.p12.rawValue)
    }

    private var fromName: String {
        participantName(debt.from)
    }

    private var toName: String {
        participantName(debt.to)
    }

    private func isViewer(_ participant: ParticipantID) -> Bool {
        participant == viewerID
    }
}

#Preview {
    let yo = Participant(displayName: "Yo")
    let iori = Participant(displayName: "Iori")
    let debt = Debt(from: yo.id, to: iori.id, amount: Money(amount: Decimal(string: "11.60") ?? 0, currency: .mxn))
    let explanation = DebtExplanation(
        debt: debt,
        debtorOwes: Money(amount: Decimal(string: "21.21") ?? 0, currency: .mxn),
        creditorCollects: Money(amount: Decimal(string: "345.77") ?? 0, currency: .mxn),
        totalOwed: Money(amount: Decimal(string: "632.27") ?? 0, currency: .mxn),
        debtorEntries: [
            BalanceEntry(
                id: EventID(),
                date: Date(timeIntervalSince1970: 1_700_000_000),
                concept: "tortas y tacos",
                amount: Money(amount: 350, currency: .mxn),
                payer: yo.id,
                share: Money(amount: Decimal(string: "43.75") ?? 0, currency: .mxn),
                effect: Decimal(string: "306.25") ?? 0),
            BalanceEntry(
                id: EventID(),
                date: Date(timeIntervalSince1970: 1_700_100_000),
                concept: "Salchichas",
                amount: Money(amount: 386, currency: .mxn),
                payer: iori.id,
                share: Money(amount: Decimal(string: "48.25") ?? 0, currency: .mxn),
                effect: -(Decimal(string: "48.25") ?? 0))
        ])
    ForEach(LanaTheme.allCases) { theme in
        DebtDetailView(
            explanation: explanation,
            viewerID: yo.id,
            participantName: { $0 == yo.id ? yo.displayName : iori.displayName })
            .lanaTheme(theme)
    }
}

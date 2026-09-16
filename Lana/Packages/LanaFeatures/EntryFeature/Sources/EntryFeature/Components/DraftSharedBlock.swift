import LanaCore
import LanaDesign
import SwiftUI

/// El bloque de gasto compartido dentro de un borrador (rediseño, sección 08).
///
/// Si la captura detectó que el gasto se comparte (ADR-0025), esto es lo único
/// que hace visible que va a una lista y no al gasto personal: sin él,
/// confirmar sería invisible hasta entrar a esa lista después. "Quitar" no
/// borra nada — revierte la detección y lo deja personal.
struct DraftSharedBlock: View {
    @Environment(\.lana) private var lana
    @Binding var draft: DraftTransaction
    let sharedLists: [SharedList]
    let viewerName: (ParticipantID, SharedListID) -> String

    var body: some View {
        if let sharedListID = draft.sharedListID,
           let list = sharedLists.first(where: { $0.id == sharedListID }) {
            VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                HairlineDivider()
                    .padding(.vertical, Space.p12.rawValue)

                HStack(spacing: Space.p6.rawValue) {
                    Image(systemName: "person.2")
                        .lanaFont(.rowSubtitle)
                        .accessibilityHidden(true)
                    Text("Compartido en \(list.name)")
                        .lanaFont(.detail)
                        .fontWeight(.medium)
                }
                .foregroundStyle(lana.ink)

                Text(splitDescription(in: list))
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink42)

                ForEach(othersShares(in: list)) { share in
                    Text("A \(viewerName(share.participant, list.id)) le toca \(share.amount.formatted())")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                }

                HStack(spacing: Space.md.rawValue) {
                    splitMenu(in: list)
                    Button("Quitar") {
                        draft.sharedListID = nil
                        draft.payer = nil
                        draft.split = nil
                    }
                    .lanaFont(.footnote)
                    .foregroundStyle(lana.ink50)
                    .buttonStyle(.plain)
                }
                .frame(minHeight: LanaMetrics.minTouchTarget)
            }
        }
    }

    /// "Lo pagaste tú · a partes iguales".
    private func splitDescription(in list: SharedList) -> String {
        let payer = draft.payer.map { viewerName($0, list.id) } ?? "Alguien"
        let payerText = payer == "Yo" ? "Lo pagaste tú" : "Lo pagó \(payer)"
        guard let split = draft.split else { return payerText }
        return "\(payerText) · \(SplitRuleKind(split).displayName.lowercased())"
    }

    /// Lo que le toca a los demás: cuánto te toca a ti ya lo dice el monto.
    private func othersShares(in list: SharedList) -> [SplitShare] {
        draft.splitShares.filter { !$0.isPayer && viewerName($0.participant, list.id) != "Yo" }
    }

    /// Cambiar la división la resuelve contra la lista al vuelo; solo se
    /// ofrecen las reglas que no piden un número por participante (ADR-0030).
    private func splitMenu(in list: SharedList) -> some View {
        Menu {
            ForEach(SplitRuleKind.resolvable(in: list)) { kind in
                Button(kind.displayName) {
                    if let resolved = kind.resolve(in: list) {
                        draft.split = resolved
                    }
                }
            }
        } label: {
            Text("Cambiar división")
                .lanaFont(.footnote)
                .foregroundStyle(lana.accent)
        }
    }
}

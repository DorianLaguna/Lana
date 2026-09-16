import LanaCore
import LanaDesign
import SwiftUI

/// El bloque de gasto compartido dentro del formulario de un movimiento
/// (rediseño, sección 14).
///
/// Aparte de `EditExpenseView` por tamaño, igual que el bloque equivalente de
/// la captura: mover un gasto entre personal y una lista sin borrarlo ni
/// volver a capturarlo (ADR-0027), y elegir cómo se divide (ADR-0030).
struct EditExpenseSharedSection: View {
    @Environment(\.lana) private var lana
    @Bindable var model: EditExpenseModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.p12.rawValue) {
            HairlineDivider()

            Menu {
                Button("Personal") {
                    model.sharedListID = nil
                    model.sharedListChanged()
                }
                ForEach(model.sharedLists) { list in
                    Button(list.name) {
                        model.sharedListID = list.id
                        model.sharedListChanged()
                    }
                }
            } label: {
                Chip(listLabel, systemImage: "person.2")
            }
            .accessibilityLabel("Lista: \(listLabel)")

            if model.sharedListID != nil {
                payerAndSplit
                shares
            }

            Text(model.sharedListID == nil
                ? "Este movimiento cuenta completo como tuyo."
                : "En tus totales solo cuenta la parte que te toca.")
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
        }
    }

    private var listLabel: String {
        guard let sharedListID = model.sharedListID,
              let list = model.sharedLists.first(where: { $0.id == sharedListID })
        else { return "Personal" }
        return "Compartido en \(list.name)"
    }

    /// Solo se ofrecen las reglas que la lista resuelve con lo que ya sabe;
    /// las que piden un número por participante se capturan en Gente.
    private var payerAndSplit: some View {
        FlowLayout {
            Menu {
                ForEach(model.participantsOfSelectedList) { participant in
                    Button(model.displayName(for: participant.id)) { model.payer = participant.id }
                }
            } label: {
                Chip("Pagó \(payerName)")
            }

            if model.effectiveSplit != nil {
                Menu {
                    ForEach(model.selectableSplitKinds) { kind in
                        Button(kind.displayName) { model.selectedSplitKind = kind }
                    }
                } label: {
                    Chip(model.selectedSplitKind?.displayName ?? "División")
                }
            }
        }
    }

    /// Cuánto le toca a cada quien con el monto y la regla vigentes del
    /// formulario (ADR-0029) — el número que los totales suman.
    private var shares: some View {
        ForEach(model.splitShares) { share in
            HStack(spacing: Space.xs.rawValue) {
                Text(model.displayName(for: share.participant))
                if share.isPayer {
                    Text("· pagó")
                }
                Spacer(minLength: Space.sm.rawValue)
                Text(share.amount.formatted())
                    .monospacedDigit()
            }
            .lanaFont(.rowSubtitle)
            .foregroundStyle(lana.ink42)
        }
    }

    private var payerName: String {
        guard let payer = model.payer else { return "alguien" }
        return model.displayName(for: payer)
    }
}

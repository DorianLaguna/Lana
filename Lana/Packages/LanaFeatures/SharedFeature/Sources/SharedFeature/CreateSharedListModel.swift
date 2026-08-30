import Foundation
import LanaCore
import Observation

/// El formulario de crear una lista compartida nueva: nombre + participantes
/// por nombre — locales por ahora, hasta que exista identidad real de
/// CKShare (Fase 8, G3). El split default siempre arranca en "por partes
/// iguales" entre todos — el más común; se puede cambiar después desde la
/// lista misma.
@MainActor
@Observable
public final class CreateSharedListModel: Identifiable {
    /// Identidad de la instancia — para presentar con `.sheet(item:)`.
    public let id = UUID()
    public var name = ""
    /// Al menos 2 casillas siempre visibles — una lista compartida de una
    /// sola persona no tiene sentido.
    public var participantNames: [String] = ["", ""]
    /// El ingreso mensual de cada participante, en el mismo orden que
    /// `participantNames` (ADR-0028). Texto, no `Decimal`: es lo que se
    /// teclea, y vacío es válido. Se pide aquí y no solo al editar porque
    /// sin ingresos una lista nueva no puede dividir proporcionalmente, y
    /// ese es el default que el usuario quiere (ADR-0030).
    public var participantIncomes: [String] = ["", ""]
    /// Índice en `participantNames` de cuál de ellos es "yo" en este
    /// dispositivo — sincroniza entre tus propios dispositivos vía tu
    /// CloudKit privado (`SharedListStore.setViewerParticipantID`,
    /// ADR-0022), nunca se comparte con los demás participantes. Solo
    /// decide cómo se ve esta lista en tu Dashboard personal. Default 0:
    /// casi siempre te escribes primero a ti mismo.
    public var viewerIndex = 0
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false

    private let sharedListStore: any SharedListStore

    public init(sharedListStore: any SharedListStore) {
        self.sharedListStore = sharedListStore
    }

    public func addParticipant() {
        participantNames.append("")
        participantIncomes.append("")
    }

    /// No deja bajar de 2 casillas — ver doc comment de `participantNames`.
    public func removeParticipant(at index: Int) {
        guard participantNames.indices.contains(index), participantNames.count > 2 else { return }
        participantNames.remove(at: index)
        if participantIncomes.indices.contains(index) {
            participantIncomes.remove(at: index)
        }
        // Si se quitó una casilla antes de la elegida, el índice elegido se
        // corre; si se quitó la elegida misma, cae de vuelta a la primera.
        if index < viewerIndex {
            viewerIndex -= 1
        } else if index == viewerIndex {
            viewerIndex = 0
        }
    }

    /// Intenta guardar. `true` si quedó guardada.
    public func save() async -> Bool {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNames = participantNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        // Se recorren los índices no vacíos en orden, no solo los nombres
        // ya filtrados — así se sabe en qué posición del roster final
        // termina el participante que se marcó como "yo" (ver `viewerIndex`).
        let survivingIndices = trimmedNames.indices.filter { !trimmedNames[$0].isEmpty }
        var hasInvalidIncome = false
        let participants = survivingIndices.map { index in
            makeParticipant(name: trimmedNames[index], incomeAt: index, hasInvalidIncome: &hasInvalidIncome)
        }

        guard !trimmedName.isEmpty else {
            errorMessage = "Ponle un nombre a la lista."
            return false
        }
        guard participants.count >= 2 else {
            errorMessage = "Se necesitan al menos 2 participantes."
            return false
        }
        guard !hasInvalidIncome else {
            errorMessage = "Revisa los ingresos: deben ser números, o quedar vacíos."
            return false
        }

        isSaving = true
        defer { isSaving = false }
        // Proporcional en cuanto haya ingresos de todos — el default que el
        // usuario pidió (ADR-0030). Sin ingresos capturados no hay
        // proporción que aplicar, y partes iguales es el único default
        // honesto.
        let equalSplit = SplitRule.equally(among: participants.map(\.id))
        let draft = SharedList(name: trimmedName, participants: participants, defaultSplit: equalSplit)
        let list = SharedList(
            id: draft.id,
            name: draft.name,
            participants: draft.participants,
            defaultSplit: draft.proportionalSplitFromIncomes ?? equalSplit)
        do {
            try await sharedListStore.save(list)
            // Si la casilla marcada como "yo" se quedó vacía, cae al primer
            // participante real — nunca deja la lista sin identidad marcada.
            let viewerPosition = survivingIndices.firstIndex(of: viewerIndex) ?? 0
            if participants.indices.contains(viewerPosition) {
                try await sharedListStore.setViewerParticipantID(participants[viewerPosition].id, for: list.id)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Un participante con su ingreso ya parseado. Un ingreso vacío es
    /// válido (`nil`); uno que no es número marca `hasInvalidIncome` para
    /// que `save()` lo reporte en vez de guardar un roster a medias.
    private func makeParticipant(
        name: String,
        incomeAt index: Int,
        hasInvalidIncome: inout Bool) -> Participant {
        let rawIncome = participantIncomes.indices.contains(index)
            ? participantIncomes[index].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        guard !rawIncome.isEmpty else {
            return Participant(displayName: name, monthlyIncome: nil)
        }
        guard let parsed = Decimal(string: rawIncome), parsed >= 0 else {
            hasInvalidIncome = true
            return Participant(displayName: name, monthlyIncome: nil)
        }
        return Participant(displayName: name, monthlyIncome: parsed)
    }
}

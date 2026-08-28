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
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false

    private let sharedListStore: any SharedListStore

    public init(sharedListStore: any SharedListStore) {
        self.sharedListStore = sharedListStore
    }

    public func addParticipant() {
        participantNames.append("")
    }

    /// No deja bajar de 2 casillas — ver doc comment de `participantNames`.
    public func removeParticipant(at index: Int) {
        guard participantNames.indices.contains(index), participantNames.count > 2 else { return }
        participantNames.remove(at: index)
    }

    /// Intenta guardar. `true` si quedó guardada.
    public func save() async -> Bool {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let participants = participantNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { Participant(displayName: $0) }

        guard !trimmedName.isEmpty else {
            errorMessage = "Ponle un nombre a la lista."
            return false
        }
        guard participants.count >= 2 else {
            errorMessage = "Se necesitan al menos 2 participantes."
            return false
        }

        isSaving = true
        defer { isSaving = false }
        let list = SharedList(
            name: trimmedName,
            participants: participants,
            defaultSplit: .equally(among: participants.map(\.id)))
        do {
            try await sharedListStore.save(list)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

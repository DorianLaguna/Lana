import Foundation
import LanaCore
import Observation

/// Una fila editable del roster. Conserva el `ParticipantID` original — sin
/// eso, renombrar a alguien lo convertiría en una persona distinta y los
/// gastos ya registrados a su nombre quedarían huérfanos.
@MainActor
@Observable
public final class EditableParticipant: Identifiable {
    public let id: ParticipantID
    public var name: String
    /// Texto, no `Decimal`: es lo que el usuario teclea. Vacío = sin ingreso
    /// capturado, que es válido (la lista entonces no divide proporcional).
    public var incomeText: String

    public init(id: ParticipantID, name: String, incomeText: String) {
        self.id = id
        self.name = name
        self.incomeText = incomeText
    }

    convenience init(_ participant: Participant) {
        self.init(
            id: participant.id,
            name: participant.displayName,
            incomeText: participant.monthlyIncome.map { "\($0)" } ?? "")
    }
}

/// Editar una lista ya creada: nombre, nombres del roster, ingresos (para
/// dividir proporcional sin teclear la proporción cada vez) y cuál
/// participante soy yo (ADR-0028).
///
/// **Quitar a alguien solo se permite si no deja dinero sin dueño**
/// (ADR-0052): si pagó algo, liquidó algo o está en una división que no es de
/// partes iguales, su saldo quedaría sin nombre que mostrar
/// (`SharedListDetailModel.load` descarta lo que no resuelve a un
/// `Participant`). Quien lo decide es `removalBlocker`; esto solo lo respeta.
@MainActor
@Observable
public final class EditSharedListModel: Identifiable {
    public let id = UUID()
    public var name: String
    public private(set) var participants: [EditableParticipant]
    public var viewerID: ParticipantID?
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false

    /// Quienes ya estaban guardados y se quitaron en esta edición.
    public private(set) var removedIDs: [ParticipantID] = []
    /// Participantes ya guardados que se sumarán a los gastos anteriores de
    /// partes iguales al guardar (ADR-0050).
    public private(set) var includeInPast: Set<ParticipantID> = []

    private let original: SharedList
    private let onSave: (SharedListEdit) async -> Bool
    private let removalBlocker: (ParticipantID) -> String?
    private let pastExpenseCounts: (ParticipantID) -> PastExpenseCounts

    /// - Parameters:
    ///   - list: la lista tal como está guardada hoy.
    ///   - viewerID: cuál participante es "yo" en este dispositivo.
    ///   - removalBlocker: por qué no se puede quitar a un participante ya
    ///     guardado, o `nil` si sí (`SharedListDetailModel.removalBlocker(for:)`).
    ///   - pastExpenseCounts: a cuántos gastos anteriores se podría sumar a
    ///     alguien, y de cuántos saldría al quitarlo.
    ///   - onSave: quién persiste el resultado — `SharedListDetailView` lo
    ///     conecta a `SharedListDetailModel`, para que la pantalla de detrás
    ///     se refresque sola.
    public init(
        list: SharedList,
        viewerID: ParticipantID?,
        removalBlocker: @escaping (ParticipantID) -> String? = { _ in nil },
        pastExpenseCounts: @escaping (ParticipantID) -> PastExpenseCounts = { _ in PastExpenseCounts() },
        onSave: @escaping (SharedListEdit) async -> Bool) {
        original = list
        name = list.name
        participants = list.participants.map(EditableParticipant.init)
        self.viewerID = viewerID
        self.removalBlocker = removalBlocker
        self.pastExpenseCounts = pastExpenseCounts
        self.onSave = onSave
    }

    /// Si el participante ya estaba guardado en la lista (y no se acaba de
    /// agregar en esta edición).
    public func isSaved(_ participant: EditableParticipant) -> Bool {
        original.participants.contains { $0.id == participant.id }
    }

    /// Por qué no se puede quitar, o `nil` si sí. Uno recién agregado siempre
    /// se puede quitar: todavía no tiene nada.
    public func blocker(for participant: EditableParticipant) -> String? {
        isSaved(participant) ? removalBlocker(participant.id) : nil
    }

    /// De cuántos gastos saldría y a cuántos anteriores se podría sumar.
    public func pastExpenses(for participant: EditableParticipant) -> PastExpenseCounts {
        isSaved(participant) ? pastExpenseCounts(participant.id) : PastExpenseCounts()
    }

    public func remove(_ participant: EditableParticipant) {
        guard blocker(for: participant) == nil else { return }
        participants.removeAll { $0.id == participant.id }
        includeInPast.remove(participant.id)
        if isSaved(participant) {
            removedIDs.append(participant.id)
        }
        if viewerID == participant.id {
            viewerID = nil
        }
    }

    public func toggleIncludeInPast(_ participant: EditableParticipant) {
        if includeInPast.contains(participant.id) {
            includeInPast.remove(participant.id)
        } else {
            includeInPast.insert(participant.id)
        }
    }

    public func addParticipant() {
        participants.append(EditableParticipant(id: ParticipantID(), name: "", incomeText: ""))
    }

    /// `true` si todos los ingresos están capturados y suman más de 0 — solo
    /// entonces la lista puede dividir proporcionalmente, y la vista lo dice
    /// en vez de dejar al usuario adivinar por qué no aparece esa opción.
    public var canSplitProportionally: Bool {
        buildParticipants().proportionalReady
    }

    public func save() async -> Bool {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Ponle un nombre a la lista."
            return false
        }
        let built = buildParticipants()
        guard built.participants.count >= 2 else {
            errorMessage = "Se necesitan al menos 2 participantes con nombre."
            return false
        }
        guard !built.hasInvalidIncome else {
            errorMessage = "Revisa los ingresos: deben ser números, o quedar vacíos."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        // El split guardado se recalcula al vuelo: proporcional si ya hay
        // ingresos de todos, si no partes iguales. Lo que ya se registró no
        // se toca — cada gasto tiene su proporción congelada (ADR-0007).
        let updated = SharedList(
            id: original.id,
            name: trimmedName,
            participants: built.participants,
            defaultSplit: .equally(among: built.participants.map(\.id)))
        let withPreferredDefault = SharedList(
            id: updated.id,
            name: updated.name,
            participants: updated.participants,
            defaultSplit: updated.proportionalSplitFromIncomes ?? updated.defaultSplit)

        let viewerStillInRoster = built.participants.contains { $0.id == viewerID }
        return await onSave(SharedListEdit(
            list: withPreferredDefault,
            viewerID: viewerStillInRoster ? viewerID : nil,
            removed: removedIDs,
            includeInPast: Array(includeInPast)))
    }

    private func buildParticipants() -> BuiltRoster {
        var result: [Participant] = []
        var hasInvalidIncome = false
        for row in participants {
            let trimmedName = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let trimmedIncome = row.incomeText.trimmingCharacters(in: .whitespacesAndNewlines)
            var income: Decimal?
            if !trimmedIncome.isEmpty {
                guard let parsed = Decimal(string: trimmedIncome), parsed >= 0 else {
                    hasInvalidIncome = true
                    continue
                }
                income = parsed
            }
            result.append(Participant(id: row.id, displayName: trimmedName, monthlyIncome: income))
        }
        return BuiltRoster(participants: result, hasInvalidIncome: hasInvalidIncome)
    }

    private struct BuiltRoster {
        let participants: [Participant]
        let hasInvalidIncome: Bool

        var proportionalReady: Bool {
            guard participants.count >= 2, !hasInvalidIncome else { return false }
            let incomes = participants.compactMap(\.monthlyIncome)
            return incomes.count == participants.count && incomes.reduce(Decimal(0), +) > 0
        }
    }
}

/// Lo que produce guardar la edición de una lista.
public struct SharedListEdit: Sendable {
    public let list: SharedList
    public let viewerID: ParticipantID?
    /// Participantes ya guardados que se quitaron: salen de sus gastos de
    /// partes iguales antes de guardar la lista (ADR-0052).
    public let removed: [ParticipantID]
    /// Participantes ya guardados que se suman a los gastos anteriores de
    /// partes iguales (ADR-0050).
    public let includeInPast: [ParticipantID]
}

/// Cuántos gastos anteriores toca una edición del roster para una persona.
public struct PastExpenseCounts: Sendable, Equatable {
    /// A cuántos gastos de partes iguales se le podría sumar.
    public var includable = 0
    /// De cuántos gastos de partes iguales saldría al quitarla.
    public var excludable = 0

    public init(includable: Int = 0, excludable: Int = 0) {
        self.includable = includable
        self.excludable = excludable
    }
}

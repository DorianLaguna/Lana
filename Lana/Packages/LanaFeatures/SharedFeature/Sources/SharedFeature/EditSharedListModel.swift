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
/// **No deja quitar participantes a propósito.** Un participante puede
/// tener gastos y liquidaciones ya registrados a su nombre; quitarlo del
/// roster no borra esos eventos, solo dejaría su saldo sin nombre que
/// mostrar (`SharedListDetailModel.load` los descarta al no resolver el
/// `Participant`), que es perder dinero de vista en silencio — justo lo que
/// Docs/CLAUDE.md prohíbe. Agregar sí es seguro y sí se puede.
@MainActor
@Observable
public final class EditSharedListModel: Identifiable {
    public let id = UUID()
    public var name: String
    public private(set) var participants: [EditableParticipant]
    public var viewerID: ParticipantID?
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false

    private let original: SharedList
    private let onSave: (SharedList, ParticipantID?) async -> Bool

    /// - Parameters:
    ///   - list: la lista tal como está guardada hoy.
    ///   - viewerID: cuál participante es "yo" en este dispositivo.
    ///   - onSave: quién persiste el resultado — `SharedListDetailView` lo
    ///     conecta a `SharedListDetailModel.updateList(_:)`/`setViewer(_:)`,
    ///     para que la pantalla de detrás se refresque sola.
    public init(
        list: SharedList,
        viewerID: ParticipantID?,
        onSave: @escaping (SharedList, ParticipantID?) async -> Bool) {
        original = list
        name = list.name
        participants = list.participants.map(EditableParticipant.init)
        self.viewerID = viewerID
        self.onSave = onSave
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
        return await onSave(withPreferredDefault, viewerStillInRoster ? viewerID : nil)
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

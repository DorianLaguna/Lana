import Foundation

public extension SharedListStore {
    /// Resuelve qué participante es "yo" en cada lista compartida que aparezca
    /// en `expenses`.
    ///
    /// Hay que resolverlo **antes** de sumar nada:
    /// `Expense.personalAmount(viewerIdentities:)` es síncrono a propósito
    /// (se llama una vez por gasto, dentro de un bucle), y consultar el store
    /// —que es `async`, ADR-0022— ahí adentro sería una llamada por
    /// transacción.
    ///
    /// Vive en `LanaCore` porque lo necesitan el Dashboard, la vista anual y el
    /// análisis, y las features no pueden importarse entre sí
    /// (Docs/ARCHITECTURE.md).
    ///
    /// Una lista cuya identidad no se pueda leer simplemente no entra al
    /// diccionario: sin identidad marcada, `personalAmount` regresa el monto
    /// completo, que es el respaldo seguro de siempre.
    func viewerIdentities(for expenses: [Expense]) async -> [SharedListID: ParticipantID] {
        await viewerIdentities(for: Array(Set(expenses.compactMap(\.sharedListID))))
    }

    /// Igual, pero partiendo de los ids directamente — el editor los necesita
    /// para todas las listas del usuario, no solo las presentes en un conjunto
    /// de gastos (ADR-0027).
    func viewerIdentities(for sharedListIDs: [SharedListID]) async -> [SharedListID: ParticipantID] {
        var identities: [SharedListID: ParticipantID] = [:]
        for sharedListID in Set(sharedListIDs) {
            if let viewerID = try? await viewerParticipantID(for: sharedListID) {
                identities[sharedListID] = viewerID
            }
        }
        return identities
    }
}

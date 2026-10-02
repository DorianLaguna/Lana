import Foundation
import LanaCore
import Observation

/// La bandeja "Por revisar": lo que se capturó solo (Apple Pay, ADR-0009) o
/// quedó dudoso al dictar, ya guardado, esperando confirmación.
///
/// Es la misma hoja de revisión que la captura (rediseño, sección 08, modo
/// bandeja), pero sobre movimientos que **ya existen**: confirmar emite una
/// corrección del mismo movimiento —mismo `id`— quitándole la marca, nunca
/// crea uno nuevo (ADR-0005).
///
/// También pregunta "¿esto es tu Netflix?" por lo que se registró sin vínculo
/// a su recurrente (ADR-0061). Cada pregunta se contesta con un toque y se
/// guarda en ese momento, aparte de "Confirmar".
@MainActor
@Observable
public final class ReviewTrayModel {
    /// Lo que espera revisión, editable antes de confirmar. `internal(set)`
    /// porque la hoja los edita con un `Binding`, igual que en la captura.
    public internal(set) var drafts: [DraftTransaction]
    /// Lo que se parece a un recurrente y todavía no se contesta.
    public private(set) var recurringSuggestions: [RecurringLinkSuggestion]
    /// Las tarjetas reales, para que el chip de forma de pago diga "Crédito Nu".
    public let cards: [Card]
    /// Las subcategorías ya usadas, por categoría.
    public let allSubcategories: [String: [String]]
    /// Las listas compartidas, para el bloque de gasto compartido.
    public let sharedLists: [SharedList]
    /// `true` mientras se confirman los movimientos.
    public private(set) var isSaving = false
    /// El último error al confirmar, si algo falló al guardar.
    public private(set) var errorMessage: String?

    private let store: any ExpenseStore

    /// - Parameter expenses: los movimientos con `needsReview`, de más
    ///   reciente a más viejo; los ordena quien los lee del store.
    ///   - recurringSuggestions: `RecurringLinking.suggestions`, de quien ya
    ///     tiene cargados los movimientos.
    public init(
        expenses: [Expense],
        recurringSuggestions: [RecurringLinkSuggestion] = [],
        store: any ExpenseStore,
        cards: [Card] = [],
        allSubcategories: [String: [String]] = [:],
        sharedLists: [SharedList] = []) {
        drafts = expenses.map(DraftTransaction.init(expense:))
        self.recurringSuggestions = recurringSuggestions
        self.store = store
        self.cards = cards
        self.allSubcategories = allSubcategories
        self.sharedLists = sharedLists
    }

    /// Cuánto queda por contestar en la bandeja.
    public var pendingCount: Int {
        drafts.count + recurringSuggestions.count
    }

    /// El texto del botón: "Confirmar los 3", "Confirmar" con uno solo, o
    /// "Listo" cuando solo quedaban preguntas de recurrentes.
    public var confirmLabel: String {
        if drafts.isEmpty {
            return "Listo"
        }
        return drafts.count > 1 ? "Confirmar los \(drafts.count)" : "Confirmar"
    }

    /// "Sí, es mi Netflix": liga el movimiento a su recurrente con una
    /// corrección. Desde ahí cuenta como recurrente y como el registro de ese
    /// mes (ADR-0042).
    public func acceptSuggestion(_ suggestion: RecurringLinkSuggestion) async {
        var linked = suggestion.expense
        linked.recurringItemID = suggestion.item.id
        await answer(suggestion, saving: linked)
    }

    /// "No es": se recuerda en el movimiento para no volver a preguntar por
    /// ese recurrente.
    public func declineSuggestion(_ suggestion: RecurringLinkSuggestion) async {
        var declined = suggestion.expense
        declined.declinedRecurringItemIDs.insert(suggestion.item.id)
        await answer(suggestion, saving: declined)
    }

    private func answer(_ suggestion: RecurringLinkSuggestion, saving expense: Expense) async {
        errorMessage = nil
        do {
            try await store.save(expense)
            recurringSuggestions.removeAll { $0.id == suggestion.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Quitar de la bandeja **no** borra el movimiento: lo deja como estaba,
    /// todavía por revisar. Para borrarlo está la edición.
    public func remove(id: ExpenseID) {
        drafts.removeAll { $0.id == id }
    }

    /// Guarda cada movimiento sin la marca de revisión, con las correcciones
    /// que se hayan hecho en la bandeja.
    ///
    /// - Returns: `false` si algo falló; el mensaje queda en `errorMessage`.
    public func confirm() async -> Bool {
        guard !drafts.isEmpty else { return true }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            for draft in drafts {
                var confirmed = draft.asExpense()
                confirmed.needsReview = false
                try await store.save(confirmed)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

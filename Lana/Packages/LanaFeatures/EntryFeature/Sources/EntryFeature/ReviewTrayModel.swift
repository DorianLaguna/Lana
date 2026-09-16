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
@MainActor
@Observable
public final class ReviewTrayModel {
    /// Lo que espera revisión, editable antes de confirmar. `internal(set)`
    /// porque la hoja los edita con un `Binding`, igual que en la captura.
    public internal(set) var drafts: [DraftTransaction]
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
    public init(
        expenses: [Expense],
        store: any ExpenseStore,
        cards: [Card] = [],
        allSubcategories: [String: [String]] = [:],
        sharedLists: [SharedList] = []) {
        drafts = expenses.map(DraftTransaction.init(expense:))
        self.store = store
        self.cards = cards
        self.allSubcategories = allSubcategories
        self.sharedLists = sharedLists
    }

    /// El texto del botón: "Confirmar los 3", o "Confirmar" con uno solo.
    public var confirmLabel: String {
        drafts.count > 1 ? "Confirmar los \(drafts.count)" : "Confirmar"
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

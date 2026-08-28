import Foundation
import LanaCore
import Observation

/// Editar un gasto/ingreso ya guardado. Guardar aquí emite una corrección
/// (Docs/CLAUDE.md — "editar emite una corrección; nada se muta en su
/// lugar"), no una transacción nueva: se llama `store.save(_:)` con el
/// mismo `id`. Si la categoría cambió respecto a la original, se registra
/// como aprendizaje (ADR-0012) — la misma regla que ya corre al confirmar
/// una captura nueva, pero antes no había ninguna forma de llegar aquí
/// desde un gasto ya guardado: Ajustes prometía "Lana aprende de tus
/// correcciones" sin que hubiera nada que corregir después de capturar.
@MainActor
@Observable
public final class EditExpenseModel: Identifiable {
    /// Identidad de la instancia — para presentar con `.sheet(item:)`, no
    /// tiene relación con `Expense.ID`.
    public let id = UUID()
    public var kind: Expense.Kind
    public var amount: Decimal
    public var concept: String
    public var category: String
    public var subcategory: String
    public var date: Date
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false
    /// Las subcategorías ya usadas alguna vez, por categoría — para el
    /// dropdown de `EditExpenseView` (mismo patrón que `EntryModel`).
    public private(set) var allSubcategories: [String: [String]] = [:]

    private let expense: Expense
    private let originalCategory: String
    private let store: any ExpenseStore
    private let vocabularyStore: any CorrectionVocabularyStore

    /// - Parameters:
    ///   - expense: el gasto/ingreso a editar.
    ///   - store: dónde se guarda la corrección.
    ///   - vocabularyStore: dónde se registra un cambio de categoría.
    public init(expense: Expense, store: any ExpenseStore, vocabularyStore: any CorrectionVocabularyStore) {
        self.expense = expense
        self.store = store
        self.vocabularyStore = vocabularyStore
        kind = expense.kind
        amount = expense.amount.amount
        concept = expense.concept
        category = expense.category ?? SuggestedCategory.otro.rawValue
        originalCategory = expense.category ?? SuggestedCategory.otro.rawValue
        subcategory = expense.subcategory ?? ""
        date = expense.date
    }

    /// Carga las subcategorías ya usadas, para el dropdown — rango amplio
    /// (2 años), filtrado y deduplicado por categoría del lado del
    /// cliente, mismo criterio que `EntryModel.onAppear()`.
    public func onAppear() async {
        guard let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) else { return }
        guard let expenses = try? await store.expenses(in: DateInterval(start: start, end: Date())) else { return }
        var bySubcategory: [String: Set<String>] = [:]
        for expense in expenses {
            guard let category = expense.category, let subcategory = expense.subcategory, !subcategory.isEmpty else {
                continue
            }
            bySubcategory[category, default: []].insert(subcategory)
        }
        allSubcategories = bySubcategory.mapValues { $0.sorted() }
    }

    /// Intenta guardar. `true` si quedó guardado — la vista decide qué
    /// hacer con eso (cerrar la hoja).
    public func save() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        if kind == .expense, category != originalCategory {
            await vocabularyStore.record(term: concept, category: category)
        }
        var updated = expense
        updated.kind = kind
        updated.amount = Money(amount: amount, currency: expense.amount.currency)
        updated.concept = concept
        updated.category = kind == .expense ? category : nil
        updated.subcategory = subcategory.isEmpty ? nil : subcategory
        updated.date = date
        // Abrir esto desde la bandeja "por revisar" y guardar ES la
        // revisión — antes se quedaba marcado igual, así que tocarlo no
        // hacía nada visible.
        updated.needsReview = false
        do {
            try await store.save(updated)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Borra el gasto/ingreso — emite una anulación, no lo mueve de la
    /// vista sin más (Docs/CLAUDE.md → "los eventos son inmutables;
    /// borrar emite una anulación"). `true` si quedó borrado.
    public func delete() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.delete(id: expense.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

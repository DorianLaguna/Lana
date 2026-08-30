import Foundation
import LanaCore
import Observation

/// El formulario de agregar/editar un ingreso o gasto recurrente. La
/// validación es la que ya tiene `RecurringItem.init` — este modelo no
/// reinventa reglas.
@MainActor
@Observable
public final class AddRecurringItemModel: Identifiable {
    /// Identidad de la instancia — para presentar con `.sheet(item:)`, no
    /// tiene relación con `RecurringItemID`.
    public let id = UUID()
    public var name: String
    public var amount: Decimal
    public var kind: Expense.Kind
    public var category: String
    public var subcategory: String
    public var dayOfMonth: Int
    /// Con qué se paga — solo aplica a gastos, igual que `category`.
    public var paymentMethod: PaymentMethod
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false
    /// Las subcategorías ya usadas alguna vez, por categoría — mismo
    /// dropdown que `EditExpenseView`.
    public private(set) var allSubcategories: [String: [String]] = [:]

    /// Las tarjetas disponibles para el selector de "con qué se paga".
    public let cards: [Card]

    /// `nil` mientras se está creando un ítem nuevo.
    private let editingItemID: RecurringItemID?
    private let lastRegisteredMonth: Date?
    private let recurringItemStore: any RecurringItemStore
    private let store: any ExpenseStore
    private let currency: Currency

    /// - Parameters:
    ///   - store: de dónde salen las subcategorías ya usadas, para el dropdown.
    ///   - editing: el ítem a editar, o `nil` para dar de alta uno nuevo.
    ///   - cards: las tarjetas disponibles, ya cargadas por quien construye esto.
    public init(
        recurringItemStore: any RecurringItemStore,
        store: any ExpenseStore,
        editing item: RecurringItem? = nil,
        cards: [Card] = [],
        currency: Currency = .mxn) {
        self.recurringItemStore = recurringItemStore
        self.store = store
        self.currency = currency
        self.cards = cards
        editingItemID = item?.id
        lastRegisteredMonth = item?.lastRegisteredMonth
        name = item?.name ?? ""
        amount = item?.amount.amount ?? 0
        kind = item?.kind ?? .expense
        category = item?.category ?? SuggestedCategory.otro.rawValue
        subcategory = item?.subcategory ?? ""
        dayOfMonth = item?.dayOfMonth ?? 1
        paymentMethod = item?.paymentMethod ?? .cash
    }

    /// Carga las subcategorías ya usadas, para el dropdown — mismo rango y
    /// criterio que `EditExpenseModel.onAppear()`.
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
        do {
            let item = try RecurringItem(
                id: editingItemID ?? RecurringItemID(),
                name: name,
                amount: Money(amount: amount, currency: currency),
                kind: kind,
                category: category.isEmpty ? nil : category,
                subcategory: subcategory.isEmpty ? nil : subcategory,
                dayOfMonth: dayOfMonth,
                paymentMethod: kind == .expense ? paymentMethod : nil,
                lastRegisteredMonth: lastRegisteredMonth)
            try await recurringItemStore.save(item)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

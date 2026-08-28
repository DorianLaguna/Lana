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
    public var dayOfMonth: Int
    /// Con qué se paga — solo aplica a gastos, igual que `category`.
    public var paymentMethod: PaymentMethod
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false

    /// Las tarjetas disponibles para el selector de "con qué se paga".
    public let cards: [Card]

    /// `nil` mientras se está creando un ítem nuevo.
    private let editingItemID: RecurringItemID?
    private let lastRegisteredMonth: Date?
    private let recurringItemStore: any RecurringItemStore
    private let currency: Currency

    /// - Parameters:
    ///   - editing: el ítem a editar, o `nil` para dar de alta uno nuevo.
    ///   - cards: las tarjetas disponibles, ya cargadas por quien construye esto.
    public init(
        recurringItemStore: any RecurringItemStore,
        editing item: RecurringItem? = nil,
        cards: [Card] = [],
        currency: Currency = .mxn) {
        self.recurringItemStore = recurringItemStore
        self.currency = currency
        self.cards = cards
        editingItemID = item?.id
        lastRegisteredMonth = item?.lastRegisteredMonth
        name = item?.name ?? ""
        amount = item?.amount.amount ?? 0
        kind = item?.kind ?? .expense
        category = item?.category ?? SuggestedCategory.otro.rawValue
        dayOfMonth = item?.dayOfMonth ?? 1
        paymentMethod = item?.paymentMethod ?? .cash
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

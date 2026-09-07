import Foundation
import LanaCore
import LanaDesign
import Observation

/// El formulario de agregar/editar tarjeta (Fase 6.5, calca
/// `AgregarTarjeta.dc.html`). La validación es la que ya tiene `Card.init`
/// — este modelo no reinventa reglas.
@MainActor
@Observable
public final class AddCardModel: Identifiable {
    /// Identidad de la instancia — para presentar con `.sheet(item:)`, no
    /// tiene relación con `CardID`.
    public let id = UUID()
    /// El nombre corto para identificar la tarjeta.
    public var alias: String
    /// Cómo le dice Wallet a esta tarjeta, si es distinto del alias — solo
    /// se usa para reconocerla en automatizaciones de Apple Pay, nunca se
    /// muestra en el resto de la app.
    public var walletMatchHint: String
    /// Los últimos 4 dígitos — nunca el número completo.
    public var lastFourDigits: String
    /// El límite de crédito.
    public var limitAmount: Decimal
    /// El día del mes en que corta el estado de cuenta (1-31).
    public var cutoffDay: Int
    /// El día del mes en que vence el pago (1-31).
    public var dueDay: Int
    /// Crédito o débito — se fija aquí, no se adivina por transacción.
    public var kind: CardKind
    /// Hex (`#RRGGBB`) para distinguirla de las demás en las listas.
    public var colorHex: String
    /// El último error, si `save()` falló.
    public private(set) var errorMessage: String?
    /// `true` mientras se está guardando.
    public private(set) var isSaving = false

    /// `nil` mientras se está creando una tarjeta nueva.
    private let editingCardID: CardID?
    private let cardStore: any CardStore
    private let currency: Currency

    /// - Parameters:
    ///   - editing: la tarjeta a editar, o `nil` para dar de alta una nueva.
    public init(cardStore: any CardStore, editing card: Card? = nil, currency: Currency = .mxn) {
        self.cardStore = cardStore
        self.currency = currency
        editingCardID = card?.id
        alias = card?.alias ?? ""
        walletMatchHint = card?.walletMatchHint ?? ""
        lastFourDigits = card?.lastFourDigits ?? ""
        limitAmount = card?.limit?.amount ?? 0
        cutoffDay = card?.cutoffDay ?? 1
        dueDay = card?.dueDay ?? 1
        kind = card?.kind ?? .credit
        colorHex = card?.colorHex ?? LanaCardColors.palette[0]
    }

    /// Intenta guardar. `true` si quedó guardada — la vista decide qué
    /// hacer con eso (cerrar la hoja).
    public func save() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            // El débito no tiene línea de crédito, corte ni fecha límite de
            // pago — lo que se haya escrito en esos campos mientras el
            // picker estaba en Crédito no se manda si el usuario terminó en
            // Débito (`Card.init` también lo descartaría, pero así ni se
            // ofrece un valor que no aplica).
            let card = try Card(
                id: editingCardID ?? CardID(),
                alias: alias,
                walletMatchHint: walletMatchHint,
                lastFourDigits: lastFourDigits,
                limit: kind == .credit ? Money(amount: limitAmount, currency: currency) : nil,
                cutoffDay: kind == .credit ? cutoffDay : nil,
                dueDay: kind == .credit ? dueDay : nil,
                kind: kind,
                colorHex: colorHex)
            try await cardStore.save(card)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

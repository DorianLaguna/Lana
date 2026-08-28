import Foundation
import LanaCore
import Observation

/// Todo lo que se ve en la pestaña Tarjetas: la lista y cuánto se debe en
/// total, por tarjeta (Fase 6.5/7.5). Usa `CardLedger` de verdad — antes
/// esto reimplementaba a mano solo "cargos del ciclo vigente", ignorando
/// pagos ya registrados.
@MainActor
@Observable
public final class CardsModel {
    /// Las tarjetas guardadas, por alias.
    public private(set) var cards: [Card] = []
    /// Cuánto se debe en total (facturado neto de pagos + ciclo abierto),
    /// por tarjeta.
    public private(set) var debtByCardID: [CardID: Money] = [:]
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar o guardar.
    public private(set) var errorMessage: String?

    private let cardStore: any CardStore
    private let store: any ExpenseStore
    private let cardPaymentStore: any CardPaymentStore
    private let calendar: Calendar

    /// - Parameters:
    ///   - cardStore: dónde se guardan y leen las tarjetas.
    ///   - store: de dónde se leen los gastos, para el detalle de cada tarjeta.
    ///   - cardPaymentStore: de dónde se leen los eventos crudos que
    ///     `CardLedger` necesita para calcular deuda total.
    public init(
        cardStore: any CardStore,
        store: any ExpenseStore,
        cardPaymentStore: any CardPaymentStore,
        calendar: Calendar = .current) {
        self.cardStore = cardStore
        self.store = store
        self.cardPaymentStore = cardPaymentStore
        self.calendar = calendar
    }

    /// Carga las tarjetas y su deuda vigente. Se llama cuando la pantalla aparece.
    public func onAppear() async {
        await load()
    }

    /// `nil` si todavía no se cargó — nunca "cero" por default, para no
    /// mostrar "sin deuda" antes de tiempo mientras carga.
    public func debt(for card: Card) -> Money? {
        debtByCardID[card.id]
    }

    /// Da de alta o edita una tarjeta (según lleve un `id` nuevo o existente).
    public func save(_ card: Card) async throws {
        try await cardStore.save(card)
        await load()
    }

    /// Elimina una tarjeta.
    public func delete(_ card: Card) async throws {
        try await cardStore.delete(id: card.id)
        await load()
    }

    /// El drill-down de una tarjeta (Fase 6.5) — `store`/`cardPaymentStore`
    /// se quedan encapsulados aquí, la vista nunca los toca directo.
    public func makeCardDetailModel(for card: Card) -> CardDetailModel {
        CardDetailModel(card: card, store: store, cardPaymentStore: cardPaymentStore, calendar: calendar)
    }

    /// El formulario de agregar (`editing: nil`) o editar una tarjeta.
    public func makeAddCardModel(editing card: Card? = nil) -> AddCardModel {
        AddCardModel(cardStore: cardStore, editing: card)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            cards = try await cardStore.cards()
            let ledger = try await CardLedger(events: cardPaymentStore.events())
            var debts: [CardID: Money] = [:]
            for card in cards {
                let statementDue = ledger.outstandingStatementBalance(for: card, asOf: Date(), calendar: calendar)
                let currentCycleAccrued = ledger.currentCycleBalance(for: card, asOf: Date(), calendar: calendar)
                debts[card.id] = (try? statementDue + currentCycleAccrued) ?? statementDue
            }
            debtByCardID = debts
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

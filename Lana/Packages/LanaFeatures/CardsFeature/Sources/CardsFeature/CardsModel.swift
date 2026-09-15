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
    /// El detalle de tarjeta que está empujado en el stack ahora mismo, si
    /// hay uno — `ContentView` lo usa para refrescarlo después de editar o
    /// borrar un gasto desde ahí. Ese editor vive en `DashboardFeature` y
    /// se presenta desde `ContentView` (las features no se importan entre
    /// sí), fuera del `NavigationStack` de `CardsView` — sin esto, borrar
    /// un gasto desde el detalle de una tarjeta lo quitaba del store pero
    /// la lista en pantalla se quedaba con la copia vieja hasta salir y
    /// volver a entrar a la tarjeta, y parecía que no se había borrado.
    /// `makeCardDetailModel` reutiliza esta MISMA instancia mientras se siga
    /// viendo la misma tarjeta — no basta con guardar la referencia si cada
    /// llamada crea una instancia nueva: `CardsView.navigationDestination`
    /// vuelve a llamar a este método en cualquier redibujado del árbol
    /// (por ejemplo cuando `cards`/`debtByCardID` cambian), y sin
    /// reutilizar la instancia, un refresco explícito llamado justo
    /// después de guardar podía terminar operando sobre una instancia ya
    /// reemplazada por una en blanco.
    public private(set) var currentCardDetailModel: CardDetailModel?
    /// `true` cuando el usuario ya recorrió la guía de Apple Pay hasta
    /// confirmarla. Solo cambia cómo se presenta la entrada en Tarjetas —de
    /// tarjeta con degradado a fila discreta—, nunca afirma que la captura
    /// automática esté funcionando: Lana no puede verificar que la
    /// automatización de Atajos exista (no hay API pública, ver
    /// `ApplePayEnvironmentProbe`), y decir "activado" sería mentir.
    public private(set) var hasSeenApplePayGuide: Bool

    private let cardStore: any CardStore
    private let store: any ExpenseStore
    private let cardPaymentStore: any CardPaymentStore
    private let calendar: Calendar
    private let userDefaults: UserDefaults

    /// Dónde vive la bandera de la guía. Pública porque el target de la app
    /// también la escribe al terminar el onboarding —ahí la guía se confirma
    /// antes de que este modelo exista— y duplicar el literal en dos módulos
    /// es cómo se desincronizan.
    public static let applePayGuideSeenDefaultsKey = "lana.applePayGuideSeen"

    /// - Parameters:
    ///   - cardStore: dónde se guardan y leen las tarjetas.
    ///   - store: de dónde se leen los gastos, para el detalle de cada tarjeta.
    ///   - cardPaymentStore: de dónde se leen los eventos crudos que
    ///     `CardLedger` necesita para calcular deuda total.
    ///   - userDefaults: dónde se persiste si la guía de Apple Pay ya se vio.
    public init(
        cardStore: any CardStore,
        store: any ExpenseStore,
        cardPaymentStore: any CardPaymentStore,
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard) {
        self.cardStore = cardStore
        self.store = store
        self.cardPaymentStore = cardPaymentStore
        self.calendar = calendar
        self.userDefaults = userDefaults
        hasSeenApplePayGuide = userDefaults.bool(forKey: Self.applePayGuideSeenDefaultsKey)
    }

    /// La guía se recorrió hasta el final y se confirmó. Persiste de
    /// inmediato: la entrada en Tarjetas tiene que bajar de volumen también
    /// tras relanzar la app.
    public func markApplePayGuideSeen() {
        hasSeenApplePayGuide = true
        userDefaults.set(true, forKey: Self.applePayGuideSeenDefaultsKey)
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
        if let existing = currentCardDetailModel, existing.card.id == card.id {
            existing.updateCard(card)
            return existing
        }
        let model = CardDetailModel(card: card, store: store, cardPaymentStore: cardPaymentStore, calendar: calendar)
        currentCardDetailModel = model
        return model
    }

    /// Refresca el detalle de tarjeta en pantalla, si hay uno — ver el
    /// comentario de `currentCardDetailModel`.
    public func refreshCurrentCardDetail() async {
        await currentCardDetailModel?.onAppear()
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

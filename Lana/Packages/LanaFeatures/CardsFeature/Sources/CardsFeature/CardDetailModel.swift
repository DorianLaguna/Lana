import Foundation
import LanaCore
import Observation

/// El drill-down de una tarjeta: cuánto se debe (total, lo que toca pagar
/// en el próximo corte, y lo que ya se facturó y sigue pendiente), el
/// desglose por categoría del ciclo vigente y la lista de transacciones
/// (Fase 6.5/7.5, calca `TarjetaDetalle.dc.html`). Solo cuenta cargos de
/// crédito (`PaymentMethod.credit`) — el débito nunca genera deuda
/// (Docs/CLAUDE.md). Usa `CardLedger` de verdad — antes esto reimplementaba
/// a mano solo "cargos del ciclo vigente" contra `ExpenseStore`, ignorando
/// que `CardLedger` ya sabe restar los pagos ya registrados.
@MainActor
@Observable
public final class CardDetailModel {
    /// La tarjeta que se está viendo. No `let`: `CardsModel.makeCardDetailModel`
    /// reutiliza esta misma instancia mientras siga empujada en el stack
    /// (para que un refresco explícito tras editar/borrar un gasto opere
    /// sobre la que de verdad está en pantalla, no sobre una recreada a
    /// medias por SwiftUI) y actualiza este campo aparte cuando la tarjeta
    /// misma cambia — antes, `Card.id` para el destino ya evitaba quedarse
    /// con datos viejos al editar la tarjeta; esto conserva eso.
    public private(set) var card: Card
    /// Los cargos de crédito a esta tarjeta, en el ciclo de corte vigente
    /// — para el desglose por categoría y la lista de transacciones.
    public private(set) var expenses: [Expense] = []
    /// Lo ya facturado en el último corte, neto de pagos registrados — lo
    /// que hay que pagar para no generar intereses.
    public private(set) var statementDue: Money = .zero(.mxn)
    /// Lo acumulado en el ciclo abierto, todavía sin facturar.
    public private(set) var currentCycleAccrued: Money = .zero(.mxn)
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar o pagar.
    public private(set) var errorMessage: String?

    private let store: any ExpenseStore
    private let cardPaymentStore: any CardPaymentStore
    private let calendar: Calendar

    /// - Parameters:
    ///   - card: la tarjeta a ver.
    ///   - store: de dónde se leen los gastos, para la lista y el desglose.
    ///   - cardPaymentStore: de dónde se leen los eventos crudos que
    ///     `CardLedger` necesita, y dónde se registra un pago nuevo.
    public init(
        card: Card,
        store: any ExpenseStore,
        cardPaymentStore: any CardPaymentStore,
        calendar: Calendar = .current) {
        self.card = card
        self.store = store
        self.cardPaymentStore = cardPaymentStore
        self.calendar = calendar
    }

    /// Cuánto se debe en total — lo ya facturado más lo que se sigue
    /// acumulando en el ciclo abierto.
    public var totalDebt: Money {
        (try? statementDue + currentCycleAccrued) ?? statementDue
    }

    /// Actualiza los datos de la tarjeta cuando `CardsModel` reutiliza esta
    /// instancia — ver el comment de `card`.
    func updateCard(_ card: Card) {
        self.card = card
    }

    /// Carga los cargos y saldos vigentes. Se llama cuando la pantalla
    /// aparece. `asOf` es inyectable (por default `Date()`, "ahora" de
    /// verdad) — mismo patrón que `RecurringItemsModel.registerDueItems(asOf:)`,
    /// para que un test pueda fijar una fecha exacta en vez de depender de
    /// la fecha real de la máquina que corre la prueba.
    public func onAppear(asOf date: Date = Date()) async {
        isLoading = true
        errorMessage = nil
        do {
            // El débito no tiene ciclo de corte — no acumula deuda, así que
            // no hay nada que cargar aquí (Docs/CLAUDE.md).
            guard let cutoffDay = card.cutoffDay else {
                expenses = []
                statementDue = .zero(.mxn)
                currentCycleAccrued = .zero(.mxn)
                isLoading = false
                return
            }
            let cycle = StatementCycle.containing(date, cutoffDay: cutoffDay, calendar: calendar)
            let all = try await store.expenses(in: DateInterval(start: cycle.start, end: cycle.end))
            expenses = all.filter { expense in
                guard case let .credit(cardID) = expense.paymentMethod else { return false }
                return cardID == card.id
            }

            let ledger = try await CardLedger(events: cardPaymentStore.events())
            statementDue = ledger.outstandingStatementBalance(for: card, asOf: date, calendar: calendar)
            currentCycleAccrued = ledger.currentCycleBalance(for: card, asOf: date, calendar: calendar)
        } catch {
            errorMessage = error.localizedDescription
            expenses = []
        }
        isLoading = false
    }

    /// Registra un pago a esta tarjeta — solo monto y fecha, un pago no es
    /// un gasto y no necesita método de pago propio. `true` si quedó
    /// registrado.
    public func recordPayment(amount: Decimal, date: Date) async -> Bool {
        guard let currency = card.limit?.currency else { return false }
        errorMessage = nil
        do {
            try await cardPaymentStore.recordPayment(CardPaymentRecorded(
                cardID: card.id,
                amount: Money(amount: amount, currency: currency),
                date: date))
            await onAppear(asOf: date)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Qué fracción del límite ya se debe (deuda total), para la barra de
    /// progreso — nunca más de 1, aunque el gasto real haya rebasado el
    /// límite. `0` en débito, que no tiene límite.
    public var limitFraction: Double {
        guard let limit = card.limit, limit.amount > 0 else { return 0 }
        let fraction = (totalDebt.amount / limit.amount) as NSDecimalNumber
        return min(1, max(0, fraction.doubleValue))
    }

    /// El desglose por categoría de los cargos del ciclo vigente.
    ///
    /// - Important: aquí cuenta el **monto completo** del cargo, no la parte
    ///   de quien mira — y por eso se construye sin `viewerIdentities`, que es
    ///   justo lo que hace a `personalAmount` regresar el total. Un gasto
    ///   compartido pagado con esta tarjeta se le debe completo al banco, sin
    ///   importar cómo se reparta después entre personas: son dos ledgers
    ///   separados y no se mezclan (Docs/CLAUDE.md). Contar aquí la mitad
    ///   diría que se debe menos de lo que va a llegar en el estado de cuenta.
    public var categoryTotals: [CategoryTotal] {
        PeriodStatistics(expenses: expenses).categoryTotals
    }

    /// Los cargos a esta tarjeta, agrupados por día.
    public var daySections: [DaySection] {
        expenses.groupedByDay(calendar: calendar)
    }
}

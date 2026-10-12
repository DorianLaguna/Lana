import Foundation
import LanaCore
import Observation

/// El drill-down de una tarjeta: cuánto se debe (total, lo que toca pagar
/// en el próximo corte, y lo que ya se facturó y sigue pendiente), el
/// desglose por categoría y la lista de transacciones del corte que se está
/// viendo —que se puede mover corte por corte hacia atrás, mientras los saldos
/// de arriba siguen siendo los de hoy (ADR-0062)—
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
    /// Los cargos de crédito a esta tarjeta en el corte que se está viendo
    /// — para el desglose por categoría y la lista de transacciones.
    public private(set) var expenses: [Expense] = []
    /// El corte que se está viendo. `nil` en débito, que no tiene ciclo.
    ///
    /// Vive en el modelo y no en un `@State` de la vista a propósito:
    /// `CardsModel.makeCardDetailModel(for:)` reutiliza esta misma instancia
    /// mientras siga empujada en el stack, y `navigationDestination` vuelve a
    /// llamarlo en cualquier redibujado — un `@State` perdería el corte elegido.
    public private(set) var selectedCycle: StatementCycle?
    /// Lo ya facturado en el último corte, neto de pagos registrados — lo
    /// que hay que pagar para no generar intereses.
    public private(set) var statementDue: Money = .zero(.mxn)
    /// Lo acumulado en el ciclo abierto, todavía sin facturar.
    public private(set) var currentCycleAccrued: Money = .zero(.mxn)
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar o pagar.
    public private(set) var errorMessage: String?

    /// Todos los cargos de crédito a esta tarjeta, de siempre — de aquí sale la
    /// rebanada de cada corte.
    ///
    /// Se cargan de una sola vez y se rebanan en memoria en vez de pedirle un
    /// rango al store por cada flechazo: `CoreDataExpenseStore.expenses(in:)`
    /// hace fetch de todos los eventos y pliega el log completo en cada llamada,
    /// así que una consulta cuesta lo mismo que la de un solo ciclo. De paso
    /// deja la navegación entre cortes sincrónica, sin spinner.
    private var charges: [Expense] = []
    /// El "ahora" de la última carga, para saber cuál es el corte vigente y
    /// cuándo el año de un corte estorba en su nombre.
    private var referenceDate = Date()

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
        referenceDate = date
        do {
            // El débito no tiene ciclo de corte — no acumula deuda, así que
            // no hay nada que cargar aquí (Docs/CLAUDE.md).
            guard let cutoffDay = card.cutoffDay else {
                charges = []
                expenses = []
                selectedCycle = nil
                statementDue = .zero(.mxn)
                currentCycleAccrued = .zero(.mxn)
                isLoading = false
                return
            }
            let current = StatementCycle.containing(date, cutoffDay: cutoffDay, calendar: calendar)
            // El tope es el cierre del corte vigente y no `date`: ese cierre cae
            // en el futuro, y un cargo con fecha de mañana ya entra en este corte.
            let all = try await store.expenses(in: DateInterval(start: .distantPast, end: current.end))
            charges = all.filter { expense in
                guard case let .credit(cardID) = expense.paymentMethod else { return false }
                return cardID == card.id
            }
            // Conserva el corte que se estaba viendo: `refreshCurrentCardDetail()`
            // corre tras editar o borrar un gasto, y regresar al corte de hoy
            // perdería el lugar del usuario. Se vuelve a resolver desde su cierre
            // para que un `cutoffDay` editado lo reacomode en un corte que existe.
            let cycle = selectedCycle
                .map { StatementCycle.containing($0.end, cutoffDay: cutoffDay, calendar: calendar) }
                ?? current
            selectedCycle = cycle
            sliceExpenses(for: cycle)

            // Los saldos son los de hoy, no los del corte que se esté viendo:
            // el saldo actual y el saldo al corte se calculan distinto y no se
            // usan indistintamente (Docs/CONVENTIONS.md).
            let ledger = try await CardLedger(events: cardPaymentStore.events())
            statementDue = ledger.outstandingStatementBalance(for: card, asOf: date, calendar: calendar)
            currentCycleAccrued = ledger.currentCycleBalance(for: card, asOf: date, calendar: calendar)
        } catch {
            errorMessage = error.localizedDescription
            charges = []
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
            // Recarga con el "ahora" de la pantalla y no con la fecha del pago:
            // registrar un pago fechado en el pasado no cambia cuál es el corte
            // vigente, y antes movía ahí los saldos y la etiqueta del selector.
            await onAppear(asOf: referenceDate)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Moverse entre cortes

    /// El corte vigente — el que contiene la fecha de la última carga.
    private var currentCycle: StatementCycle? {
        guard let cutoffDay = card.cutoffDay else { return nil }
        return .containing(referenceDate, cutoffDay: cutoffDay, calendar: calendar)
    }

    /// `true` si queda algún cargo más viejo que el corte que se está viendo.
    ///
    /// Se apaga la flecha en vez de dejar pasear por cortes vacíos: una tarjeta
    /// que empezó antes de usar Lana solo trae lo que se registró (ADR-0060).
    public var canGoToPreviousCycle: Bool {
        guard let cycle = selectedCycle else { return false }
        return charges.contains { $0.date <= cycle.start }
    }

    /// `false` en el corte vigente: no hay nada que ver adelante.
    public var canGoToNextCycle: Bool {
        guard let cycle = selectedCycle, let current = currentCycle else { return false }
        return cycle.end < current.end
    }

    /// `true` cuando se está viendo el corte abierto — de eso depende qué decir
    /// si no hay movimientos.
    public var isViewingCurrentCycle: Bool {
        guard let cycle = selectedCycle, let current = currentCycle else { return true }
        return cycle.end == current.end
    }

    /// "Corte del 12 de octubre". `nil` en débito.
    public var cycleLabel: String? {
        guard let cycle = selectedCycle else { return nil }
        return LanaDateFormat.cycleName(end: cycle.end, calendar: calendar, now: referenceDate)
    }

    /// Se mueve al corte anterior. Sincrónica: los cargos ya están cargados y
    /// solo hay que volver a rebanarlos.
    public func goToPreviousCycle() {
        guard canGoToPreviousCycle,
              let cutoffDay = card.cutoffDay,
              let cycle = selectedCycle else { return }
        let previous = cycle.previous(cutoffDay: cutoffDay, calendar: calendar)
        selectedCycle = previous
        sliceExpenses(for: previous)
    }

    /// Se mueve al corte siguiente, sin pasarse del vigente.
    public func goToNextCycle() {
        guard canGoToNextCycle,
              let cutoffDay = card.cutoffDay,
              let cycle = selectedCycle else { return }
        let next = cycle.next(cutoffDay: cutoffDay, calendar: calendar)
        selectedCycle = next
        sliceExpenses(for: next)
    }

    /// Los cargos de un corte, de entre todos los de la tarjeta.
    ///
    /// Filtra con `StatementCycle.contains(_:)` y no con `DateInterval`: el ciclo
    /// es `(start, end]` y `DateInterval` incluye los dos extremos, así que un
    /// cargo justo en la medianoche del corte saldría en dos cortes distintos.
    private func sliceExpenses(for cycle: StatementCycle) {
        expenses = charges.filter { cycle.contains($0.date) }
    }

    // MARK: - Límite

    /// Qué fracción del límite ya se debe (deuda total), para la barra de
    /// progreso — nunca más de 1, aunque el gasto real haya rebasado el
    /// límite. `0` en débito, que no tiene límite.
    public var limitFraction: Double {
        guard let limit = card.limit, limit.amount > 0 else { return 0 }
        let fraction = (totalDebt.amount / limit.amount) as NSDecimalNumber
        return min(1, max(0, fraction.doubleValue))
    }

    /// "63%", o "menos de 1%" — cuánto del límite se debe, para el texto sobre
    /// la barra. `nil` sin límite registrado.
    public var limitUsage: String? {
        guard let limit = card.limit else { return nil }
        return limitUsageText(debt: totalDebt.amount, limit: limit.amount)
    }

    /// El desglose por categoría de los cargos del corte que se está viendo.
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

    /// Los cargos a esta tarjeta en el corte que se está viendo, por día.
    public var daySections: [DaySection] {
        expenses.groupedByDay(calendar: calendar)
    }
}

/// Cuánto del límite se debe, como texto: "63%", o "menos de 1%" cuando ya hay
/// deuda pero no llega al 1 % — decir "0%" con cargos encima parecía un error.
/// `nil` si no hay límite.
///
/// Libre y no dentro de una vista: `swift test` truena al tocar miembros de un
/// tipo `View`.
func limitUsageText(debt: Decimal, limit: Decimal) -> String? {
    guard limit > 0 else { return nil }
    let percent = Percentage.rounded(debt, of: limit)
    if percent == 0, debt > 0 {
        return "menos de 1%"
    }
    return "\(percent)%"
}

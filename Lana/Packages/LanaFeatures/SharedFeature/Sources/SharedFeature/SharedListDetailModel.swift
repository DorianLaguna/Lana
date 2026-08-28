import Foundation
import LanaCore
import Observation

/// El drill-down de una lista compartida: saldos (con tendencia, ADR-0008),
/// gastos, capturar uno nuevo, liquidar. `list` es la foto del momento en
/// que se entró — el nombre/roster no cambian aquí (eso es otra pantalla).
@MainActor
@Observable
public final class SharedListDetailModel {
    /// La foto del momento en que se entró — el nombre/roster no cambian
    /// aquí (eso es otra pantalla).
    public let list: SharedList
    /// El saldo de cada participante, con tendencia (ADR-0008).
    public private(set) var balances: [ParticipantBalance] = []
    /// Las transferencias mínimas que saldarían los saldos vigentes.
    public private(set) var debts: [Debt] = []
    /// Los gastos de esta lista, más reciente primero.
    public private(set) var expenses: [Expense] = []
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar o guardar.
    public private(set) var errorMessage: String?

    private let sharedListStore: any SharedListStore
    private let expenseStore: any ExpenseStore
    private let calendar: Calendar

    /// - Parameters:
    ///   - list: la lista compartida a mostrar.
    ///   - sharedListStore: dónde se leen los eventos crudos (para
    ///     `PersonLedger`) y se registran liquidaciones.
    ///   - expenseStore: dónde se guardan/leen los gastos — un gasto
    ///     compartido es un gasto más, mismo camino que uno personal.
    public init(
        list: SharedList,
        sharedListStore: any SharedListStore,
        expenseStore: any ExpenseStore,
        calendar: Calendar = .current) {
        self.list = list
        self.sharedListStore = sharedListStore
        self.expenseStore = expenseStore
        self.calendar = calendar
    }

    /// Se llama cuando la pantalla aparece: carga saldos, deudas y gastos.
    public func onAppear(asOf date: Date = Date()) async {
        await load(asOf: date)
    }

    /// Resuelve el nombre a mostrar de un participante — `nil` si ya no
    /// está en el roster (no debería pasar, pero un `Debt`/gasto viejo
    /// podría referenciar a alguien que se quitó de la lista).
    public func participant(_ id: ParticipantID) -> Participant? {
        list.participants.first { $0.id == id }
    }

    /// Registra un gasto de esta lista — mismo camino de escritura que
    /// cualquier otro gasto (`ExpenseStore.save(_:)`); `sharedListID`/
    /// `payer`/`split` son lo único que lo distingue de uno personal.
    public func recordExpense(
        amount: Money,
        concept: String,
        date: Date,
        payer: ParticipantID,
        split: SplitRule) async -> Bool {
        errorMessage = nil
        do {
            try await expenseStore.save(Expense(
                kind: .expense,
                amount: amount,
                concept: concept,
                date: date,
                sharedListID: list.id,
                payer: payer,
                split: split))
            await load(asOf: Date())
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Registra que `from` le pagó a `to` para saldar (parte de) su deuda.
    public func recordSettlement(
        from: ParticipantID,
        to: ParticipantID,
        amount: Decimal,
        currency: Currency,
        date: Date) async -> Bool {
        errorMessage = nil
        do {
            try await sharedListStore.recordSettlement(SettlementRecorded(
                sharedListID: list.id,
                from: from,
                to: to,
                amount: Money(amount: amount, currency: currency),
                paymentMethod: .cash,
                date: date))
            await load(asOf: Date())
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func load(asOf date: Date) async {
        isLoading = true
        errorMessage = nil
        do {
            let allEvents = try await sharedListStore.events()
            let currentLedger = PersonLedger(events: allEvents)

            // Tendencia: mismo log plegado hasta un corte de hace 30 días,
            // comparado contra el saldo vigente — sin dominio nuevo
            // (ADR-0008: "la vista de saldo compartido prioriza la
            // tendencia sobre el número puntual").
            let cutoff = calendar.date(byAdding: .day, value: -30, to: date) ?? date
            let pastLedger = PersonLedger(events: allEvents.filter { $0.recordedAt <= cutoff })

            let currentByCurrency = currentLedger.netBalances(in: list.id)
            let pastByCurrency = pastLedger.netBalances(in: list.id)

            balances = currentByCurrency.flatMap { currency, byParticipant in
                byParticipant.compactMap { participantID, amount -> ParticipantBalance? in
                    guard amount != 0, let participant = participant(participantID) else { return nil }
                    let pastAmount = pastByCurrency[currency]?[participantID] ?? 0
                    let trend: ParticipantBalance.Trend = if abs(amount) > abs(pastAmount) {
                        .growing
                    } else if abs(amount) < abs(pastAmount) {
                        .shrinking
                    } else {
                        .stable
                    }
                    return ParticipantBalance(
                        participant: participant,
                        amount: amount,
                        currency: currency,
                        trend: trend)
                }
            }.sorted { $0.participant.displayName < $1.participant.displayName }

            debts = currentByCurrency.keys.flatMap { currentLedger.simplifiedDebts(in: list.id, currency: $0) }

            let wideRange = DateInterval(
                start: calendar.date(byAdding: .year, value: -5, to: date) ?? .distantPast,
                end: date)
            expenses = try await expenseStore.expenses(in: wideRange)
                .filter { $0.sharedListID == list.id }
                .sorted { $0.date > $1.date }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

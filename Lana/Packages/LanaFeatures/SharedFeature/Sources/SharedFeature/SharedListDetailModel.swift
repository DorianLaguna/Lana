import Foundation
import LanaCore
import Observation

/// El drill-down de una lista compartida: saldos (con tendencia, ADR-0008),
/// gastos, capturar uno nuevo, liquidar, y editar la lista misma
/// (`updateList(_:)`, ADR-0028).
@MainActor
@Observable
public final class SharedListDetailModel {
    /// El nombre/roster vigentes. `private(set) var` y no `let` desde
    /// ADR-0028: editar la lista (nombre, nombres de participantes,
    /// ingresos) pasa por `updateList(_:)` y se refleja aquí mismo, sin
    /// tener que salir y volver a entrar.
    public private(set) var list: SharedList
    /// Cuál participante es "yo" en este dispositivo (ADR-0022). Se usa
    /// para mostrar "Yo" en vez del nombre propio en toda la pantalla
    /// (`displayName(for:)`) — pedido explícito del usuario.
    public private(set) var viewerParticipantID: ParticipantID?
    /// El saldo de cada participante, con tendencia (ADR-0008).
    public private(set) var balances: [ParticipantBalance] = []
    /// Quién le paga a quién para quedar a mano: cada quien paga o cobra su
    /// saldo, ni más ni menos (ADR-0053).
    public private(set) var debts: [Debt] = []
    /// Los gastos de esta lista, más reciente primero.
    public private(set) var expenses: [Expense] = []
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar o guardar.
    public private(set) var errorMessage: String?
    /// La URL de invitación, una vez preparada (ADR-0020). `nil` hasta que
    /// se llama `prepareShare()`.
    public private(set) var shareURL: URL?
    /// Por qué no se pudo preparar el share — nunca sobrescribe
    /// `errorMessage` de cargar/guardar, es su propio estado.
    public private(set) var shareErrorMessage: String?
    /// `true` si nadie marcó todavía cuál de los participantes es "yo" en
    /// este dispositivo (`SharedListStore.viewerParticipantID`, ADR-0022) —
    /// listas creadas antes de que esto existiera, o recibidas por
    /// invitación, no lo tienen. La vista muestra un prompt mientras esto
    /// sea `true`. Se recalcula en cada `onAppear()`, así que si el usuario
    /// ya lo marcó en otro de sus dispositivos, deja de pedirse solo en
    /// cuanto ese dato sincronice.
    public private(set) var needsViewerPrompt = false

    private let sharedListStore: any SharedListStore
    private let expenseStore: any ExpenseStore
    private let parser: any ExpenseParsing
    private let calendar: Calendar
    /// El log crudo de la última carga — se guarda solo para
    /// `contributions(for:)`, que necesita volver a plegar eventos con un
    /// par de participantes distinto en cada tap; evita pedirlo de nuevo al
    /// store cada vez que se abre el detalle de una deuda.
    private var events: [ExpenseEvent] = []

    /// - Parameters:
    ///   - list: la lista compartida a mostrar.
    ///   - sharedListStore: dónde se leen los eventos crudos (para
    ///     `PersonLedger`), se registran liquidaciones, y se lee/marca
    ///     `viewerParticipantID`.
    ///   - expenseStore: dónde se guardan/leen los gastos — un gasto
    ///     compartido es un gasto más, mismo camino que uno personal.
    ///   - parser: para sugerir categoría/subcategoría del concepto escrito
    ///     — mismo parser que la captura personal, nunca su propio modelo
    ///     (Docs/CLAUDE.md).
    public init(
        list: SharedList,
        sharedListStore: any SharedListStore,
        expenseStore: any ExpenseStore,
        parser: any ExpenseParsing,
        calendar: Calendar = .current) {
        self.list = list
        self.sharedListStore = sharedListStore
        self.expenseStore = expenseStore
        self.parser = parser
        self.calendar = calendar
    }

    /// Marca cuál participante es "yo" en este dispositivo — sincroniza
    /// entre tus propios dispositivos vía tu CloudKit privado, nunca se
    /// comparte con los demás participantes (ADR-0022). Decide cómo se ve
    /// esta lista en tu Dashboard personal (`Expense.personalAmount`).
    public func setViewer(_ participantID: ParticipantID) async {
        errorMessage = nil
        do {
            try await sharedListStore.setViewerParticipantID(participantID, for: list.id)
            viewerParticipantID = participantID
            needsViewerPrompt = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Se llama cuando la pantalla aparece: carga saldos, deudas, gastos, y
    /// si hace falta preguntar quién es el usuario en esta lista.
    public func onAppear(asOf date: Date = Date()) async {
        viewerParticipantID = await (try? sharedListStore.viewerParticipantID(for: list.id)) ?? nil
        needsViewerPrompt = viewerParticipantID == nil
        await load(asOf: date)
    }

    /// El nombre a mostrar de un participante, con "Yo" en lugar del nombre
    /// propio — la regla vive en `SharedList.displayName(for:viewer:)`, una
    /// sola vez para los tres módulos que la muestran.
    public func displayName(for id: ParticipantID) -> String {
        list.displayName(for: id, viewer: viewerParticipantID)
    }

    /// Guarda cambios de nombre de la lista, nombres de participantes e
    /// ingresos (ADR-0028). El roster conserva los `ParticipantID`
    /// existentes — cambiar un nombre no puede reasignar los gastos ya
    /// registrados a otra persona.
    public func updateList(_ updated: SharedList) async -> Bool {
        errorMessage = nil
        do {
            try await sharedListStore.save(updated)
            list = updated
            await load(asOf: Date())
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Los gastos ya registrados a los que se podría sumar a `newcomers`: los
    /// de partes iguales que todavía no los incluyen (ADR-0050).
    public func expensesToInclude(_ newcomers: [ParticipantID]) -> [Expense] {
        expenses.filter { $0.split?.including(newcomers) != nil }
    }

    /// Suma a `newcomers` a los gastos de partes iguales ya registrados. Cada
    /// uno emite una corrección de su división —nada se reescribe ni se
    /// borra—, así que los saldos se recalculan solos (ADR-0050).
    ///
    /// - Returns: `false` si algún gasto no se pudo corregir; los que sí se
    ///   guardaron se quedan corregidos.
    public func include(_ newcomers: [ParticipantID]) async -> Bool {
        await correctSplits { $0.including(newcomers) }
    }

    /// Los gastos de partes iguales de los que saldría `leaving` al quitarlo
    /// de la lista (ADR-0052).
    public func expensesToExclude(_ leaving: [ParticipantID]) -> [Expense] {
        expenses.filter { $0.split?.excluding(leaving) != nil }
    }

    /// Saca a `leaving` de los gastos de partes iguales en que estaba; se
    /// dividen entre los demás. Cada uno es una corrección (ADR-0052). Solo
    /// tiene sentido para quien no tiene `removalBlocker(for:)`.
    public func exclude(_ leaving: [ParticipantID]) async -> Bool {
        await correctSplits { $0.excluding(leaving) }
    }

    /// Por qué no se puede quitar a alguien de la lista sin perder dinero de
    /// vista, o `nil` si sí se puede (ADR-0052). Quitar solo es seguro cuando
    /// su única huella son partes de gastos iguales, que se reparten entre
    /// los demás; lo que pagó o liquidó no tiene a dónde irse.
    public func removalBlocker(for participant: ParticipantID) -> String? {
        if participant == viewerParticipantID {
            return "Eres tú en esta lista."
        }
        if expenses.contains(where: { $0.payer == participant }) {
            return "Pagó gastos en esta lista."
        }
        let hasSettlements = events.contains { event in
            guard case let .settlementRecorded(settlement) = event, settlement.sharedListID == list.id else {
                return false
            }
            return settlement.from == participant || settlement.to == participant
        }
        if hasSettlements {
            return "Tiene pagos registrados en esta lista."
        }
        let inOtherSplits = expenses.contains { expense in
            guard let split = expense.split, split.excluding([participant]) == nil else { return false }
            return (try? split.portions(of: expense.amount))?[participant] != nil
        }
        if inOtherSplits {
            return "Está en gastos divididos por porcentaje o montos."
        }
        return nil
    }

    /// Corrige la división de cada gasto que `transform` cambie.
    private func correctSplits(_ transform: (SplitRule) -> SplitRule?) async -> Bool {
        errorMessage = nil
        var succeeded = true
        for var expense in expenses {
            guard let split = expense.split.flatMap(transform) else { continue }
            expense.split = split
            do {
                try await expenseStore.save(expense)
            } catch {
                errorMessage = error.localizedDescription
                succeeded = false
            }
        }
        await load(asOf: Date())
        return succeeded
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
        category: String? = nil,
        subcategory: String? = nil,
        date: Date,
        payer: ParticipantID,
        split: SplitRule) async -> Bool {
        errorMessage = nil
        do {
            try await expenseStore.save(Expense(
                kind: .expense,
                amount: amount,
                concept: concept,
                category: category,
                subcategory: subcategory,
                date: date,
                sharedListID: list.id,
                payer: payer,
                split: split,
                source: .manual))
            await load(asOf: Date())
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Corrige un gasto ya guardado de esta lista — mismo `id`, así que
    /// `ExpenseStore.save(_:)` lo trata como corrección, no como uno nuevo
    /// (Docs/CLAUDE.md: "editar emite una corrección, nada se muta en su
    /// lugar"). A diferencia de `EditExpenseModel` (Dashboard), esto sí deja
    /// cambiar `payer`/`split` — lo que un gasto compartido necesita editar
    /// de verdad y el editor genérico no tiene cómo mostrar (no conoce el
    /// roster de participantes).
    public func updateExpense(
        id: Expense.ID,
        amount: Money,
        concept: String,
        category: String? = nil,
        subcategory: String? = nil,
        date: Date = Date(),
        payer: ParticipantID,
        split: SplitRule) async -> Bool {
        errorMessage = nil
        do {
            try await expenseStore.save(Expense(
                id: id,
                kind: .expense,
                amount: amount,
                concept: concept,
                category: category,
                subcategory: subcategory,
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

    /// Saca un gasto de la lista y lo deja como personal, conservándolo
    /// (ADR-0027). Emite una corrección con `clearsSharedContext`, no una
    /// anulación: el gasto sigue existiendo con el mismo `id` y su
    /// historial completo, solo deja de contar en los saldos entre personas
    /// y pasa a valer completo en el Dashboard.
    public func convertToPersonal(id: Expense.ID) async -> Bool {
        errorMessage = nil
        guard let expense = expenses.first(where: { $0.id == id }) else {
            errorMessage = "No se encontró el gasto."
            return false
        }
        do {
            try await expenseStore.save(Expense(
                id: expense.id,
                kind: expense.kind,
                amount: expense.amount,
                concept: expense.concept,
                category: expense.category,
                subcategory: expense.subcategory,
                date: expense.date,
                paymentMethod: expense.paymentMethod,
                needsReview: expense.needsReview,
                sharedListID: nil,
                payer: nil,
                split: nil))
            await load(asOf: Date())
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Borra un gasto de esta lista — emite una anulación
    /// (`ExpenseStore.delete(id:)`), no lo mueve de la vista sin más.
    public func deleteExpense(id: Expense.ID) async -> Bool {
        errorMessage = nil
        do {
            try await expenseStore.delete(id: id)
            await load(asOf: Date())
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Sugiere categoría/subcategoría a partir del concepto escrito, para
    /// prellenar (nunca bloquear) el picker de categoría de
    /// `SharedExpenseCaptureView` — mismo parser que la captura personal,
    /// pidiéndole solo esto: el monto y la fecha del formulario ya son
    /// ciertos, nunca se le piden al modelo (mismo criterio que el App
    /// Intent de Apple Pay, ADR-0019). `nil` si el modelo no está
    /// disponible, el concepto está vacío, o no propuso nada.
    public func suggestCategory(for concept: String) async -> ParseResult? {
        let trimmed = concept.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, await parser.availability == .available else { return nil }
        return try? await parser.parse(trimmed).first
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

    /// Prepara (o reutiliza) la invitación de `CKShare` para esta lista
    /// (ADR-0020). `shareURL` queda en `nil` sin cuenta de iCloud activa —
    /// no es un error, es el modo local de siempre.
    public func prepareShare() async {
        shareErrorMessage = nil
        do {
            shareURL = try await sharedListStore.shareURL(for: list.id)
            if shareURL == nil {
                shareErrorMessage = """
                No se detectó una cuenta de iCloud activa cuando se abrió la app. Si ya iniciaste \
                sesión en iCloud, cierra Lana por completo y vuelve a abrirla.
                """
            }
        } catch {
            shareErrorMessage = error.localizedDescription
        }
    }

    /// De dónde sale una fila de "Para quedar a mano" (ADR-0053): el saldo
    /// total de quien debe, qué parte de lo que se debe en la lista cobra
    /// quien recibe, y los movimientos que formaron ese saldo.
    public func explanation(for debt: Debt) -> DebtExplanation {
        let ledger = PersonLedger(events: events)
        let currency = debt.amount.currency
        let balances = ledger.netBalances(in: list.id)[currency] ?? [:]
        let totalOwed = balances.values.filter { $0 > 0 }.reduce(Decimal(0), +)
        return DebtExplanation(
            debt: debt,
            debtorOwes: Money(amount: -(balances[debt.from] ?? 0), currency: currency),
            creditorCollects: Money(amount: balances[debt.to] ?? 0, currency: currency),
            totalOwed: Money(amount: totalOwed, currency: currency),
            debtorEntries: ledger.balanceEntries(for: debt.from, in: list.id, currency: currency))
    }

    private func load(asOf date: Date) async {
        isLoading = true
        errorMessage = nil
        do {
            let allEvents = try await sharedListStore.events()
            events = allEvents
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

            debts = currentByCurrency.keys.flatMap { currentLedger.settlementPlan(in: list.id, currency: $0) }

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

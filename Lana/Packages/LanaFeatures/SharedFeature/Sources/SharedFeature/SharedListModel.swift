import Foundation
import LanaCore
import Observation

/// Todo lo que se ve en la pestaña Compartido: la lista de listas
/// compartidas (Fase 8). La vista no decide nada — solo refleja esto
/// (Docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class SharedListModel {
    /// Las listas guardadas, por nombre.
    public private(set) var lists: [SharedList] = []
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar o guardar.
    public private(set) var errorMessage: String?
    /// El detalle de lista que está empujado en el stack ahora mismo, si
    /// hay uno — `ContentView`/`DashboardView` lo usan para refrescarlo
    /// después de editar o borrar un gasto compartido desde otra pestaña
    /// (Dashboard o Tarjetas). `makeDetailModel` reutiliza esta MISMA
    /// instancia mientras se siga viendo la misma lista — mismo motivo que
    /// `CardsModel.currentCardDetailModel`: sin reutilizar la instancia, un
    /// refresco explícito llamado después de guardar podía terminar
    /// operando sobre una instancia ya reemplazada. Sin este refresco
    /// cruzado, borrar un gasto compartido desde el Dashboard lo quitaba
    /// del store pero el saldo en "Compartido" se quedaba con la cifra
    /// vieja hasta salir y volver a entrar a la lista.
    public private(set) var currentDetailModel: SharedListDetailModel?
    /// Cuánto te deben (positivo) o debes (negativo) sumando todas las listas,
    /// por moneda — la cifra que abre Gente. Se deriva plegando los eventos
    /// una sola vez, nunca se guarda (ADR-0005).
    public private(set) var netBalance: [Money] = []
    /// Las deudas vigentes de cada lista, para la línea "Renata te debe" y su
    /// botón de liquidar.
    public private(set) var debtsByList: [SharedListID: [Debt]] = [:]
    /// Cuántos gastos lleva cada lista.
    public private(set) var expenseCountByList: [SharedListID: Int] = [:]
    /// Quién eres tú en cada lista (ADR-0022) — para decir "Yo" y para saber
    /// de qué lado cae cada saldo.
    public private(set) var viewerIdentities: [SharedListID: ParticipantID] = [:]

    private let sharedListStore: any SharedListStore
    private let expenseStore: any ExpenseStore
    private let parser: any ExpenseParsing

    /// - Parameters:
    ///   - sharedListStore: dónde se guardan y leen las listas.
    ///   - expenseStore: de dónde se leen/guardan los gastos compartidos —
    ///     un gasto de lista compartida es un gasto más, mismo camino de
    ///     escritura que uno personal (`Expense.sharedListID`).
    ///   - parser: para sugerir categoría/subcategoría al capturar un gasto
    ///     compartido — se pasa tal cual a `SharedListDetailModel`.
    public init(sharedListStore: any SharedListStore, expenseStore: any ExpenseStore, parser: any ExpenseParsing) {
        self.sharedListStore = sharedListStore
        self.expenseStore = expenseStore
        self.parser = parser
    }

    /// Se llama cuando la pantalla aparece: carga las listas guardadas.
    public func onAppear() async {
        await load()
    }

    /// Borra una lista completa, con su historial (ver doc comment de
    /// `SharedListStore.delete` — un borrado más grueso que anular un
    /// gasto).
    public func delete(_ list: SharedList) async {
        errorMessage = nil
        do {
            try await sharedListStore.delete(id: list.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// El drill-down de una lista: saldos, gastos, capturar, liquidar.
    public func makeDetailModel(for list: SharedList) -> SharedListDetailModel {
        if let existing = currentDetailModel, existing.list.id == list.id {
            return existing
        }
        let model = SharedListDetailModel(
            list: list,
            sharedListStore: sharedListStore,
            expenseStore: expenseStore,
            parser: parser)
        currentDetailModel = model
        return model
    }

    /// Refresca el detalle de lista en pantalla, si hay uno — ver el
    /// comentario de `currentDetailModel`.
    public func refreshCurrentDetail() async {
        await currentDetailModel?.onAppear()
    }

    /// El formulario de crear una lista nueva.
    public func makeCreateModel() -> CreateSharedListModel {
        CreateSharedListModel(sharedListStore: sharedListStore)
    }

    /// El nombre a mostrar de un participante en una lista, con "Yo" en lugar
    /// del nombre propio — la misma regla que usa el detalle (ADR-0028).
    public func displayName(for participantID: ParticipantID, in list: SharedList) -> String {
        list.displayName(for: participantID, viewer: viewerIdentities[list.id])
    }

    /// Las deudas de una lista donde tú estás de un lado o del otro. Las de
    /// terceros entre sí no son asunto de esta pantalla.
    public func debtsInvolvingViewer(in list: SharedList) -> [Debt] {
        guard let viewer = viewerIdentities[list.id] else { return [] }
        return (debtsByList[list.id] ?? []).filter { $0.from == viewer || $0.to == viewer }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            lists = try await sharedListStore.lists()
            viewerIdentities = await sharedListStore.viewerIdentities(for: lists.map(\.id))
            let ledger = try await PersonLedger(events: sharedListStore.events())
            deriveBalances(with: ledger)
            await countExpenses()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Pliega el log una sola vez para todas las listas: el saldo propio de
    /// cada una, sumado por moneda, y las transferencias que lo saldarían.
    private func deriveBalances(with ledger: PersonLedger) {
        var totals: [Currency: Decimal] = [:]
        var debts: [SharedListID: [Debt]] = [:]
        for list in lists {
            let byCurrency = ledger.netBalances(in: list.id)
            if let viewer = viewerIdentities[list.id] {
                for (currency, byParticipant) in byCurrency {
                    totals[currency, default: 0] += byParticipant[viewer] ?? 0
                }
            }
            debts[list.id] = byCurrency.keys.flatMap { ledger.simplifiedDebts(in: list.id, currency: $0) }
        }
        netBalance = totals
            .filter { $0.value != 0 }
            .map { Money(amount: $0.value, currency: $0.key) }
            .sorted { $0.currency.rawValue < $1.currency.rawValue }
        debtsByList = debts
    }

    private func countExpenses() async {
        guard let start = Calendar.current.date(byAdding: .year, value: -5, to: Date()) else { return }
        let range = DateInterval(start: start, end: Date())
        guard let expenses = try? await expenseStore.expenses(in: range) else { return }
        var counts: [SharedListID: Int] = [:]
        for expense in expenses {
            guard let listID = expense.sharedListID else { continue }
            counts[listID, default: 0] += 1
        }
        expenseCountByList = counts
    }
}

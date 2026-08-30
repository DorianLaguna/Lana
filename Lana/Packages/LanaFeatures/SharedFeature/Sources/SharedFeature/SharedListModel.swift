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

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            lists = try await sharedListStore.lists()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

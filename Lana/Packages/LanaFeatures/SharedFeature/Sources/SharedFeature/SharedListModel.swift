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

    private let sharedListStore: any SharedListStore
    private let expenseStore: any ExpenseStore

    /// - Parameters:
    ///   - sharedListStore: dónde se guardan y leen las listas.
    ///   - expenseStore: de dónde se leen/guardan los gastos compartidos —
    ///     un gasto de lista compartida es un gasto más, mismo camino de
    ///     escritura que uno personal (`Expense.sharedListID`).
    public init(sharedListStore: any SharedListStore, expenseStore: any ExpenseStore) {
        self.sharedListStore = sharedListStore
        self.expenseStore = expenseStore
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
        SharedListDetailModel(list: list, sharedListStore: sharedListStore, expenseStore: expenseStore)
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

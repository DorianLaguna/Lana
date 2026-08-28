import Foundation
import LanaCore
import Observation

/// Ingresos y gastos recurrentes (sueldo, renta, suscripciones): la lista,
/// el registro manual con un toque y el registro automático de lo que ya
/// venció (`registerDueItems()`) — ver su doc comment para el porqué del
/// cambio de diseño.
@MainActor
@Observable
public final class RecurringItemsModel {
    /// Los ingresos/gastos recurrentes guardados.
    public private(set) var items: [RecurringItem] = []
    /// Las tarjetas guardadas — para el selector de "con qué se paga" al
    /// dar de alta o editar un recurrente.
    public private(set) var cards: [Card] = []
    /// `true` mientras se está cargando.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar o guardar.
    public private(set) var errorMessage: String?

    private let recurringItemStore: any RecurringItemStore
    private let store: any ExpenseStore
    private let cardStore: any CardStore

    /// - Parameters:
    ///   - recurringItemStore: dónde se guardan y leen los recurrentes.
    ///   - store: dónde se guarda un gasto/ingreso al registrar una ocurrencia.
    ///   - cardStore: dónde se leen las tarjetas, para el selector de pago.
    public init(recurringItemStore: any RecurringItemStore, store: any ExpenseStore, cardStore: any CardStore) {
        self.recurringItemStore = recurringItemStore
        self.store = store
        self.cardStore = cardStore
    }

    /// Carga los recurrentes guardados. Se llama cuando la pantalla aparece.
    public func onAppear() async {
        await load()
    }

    /// Da de alta o edita un recurrente (según lleve un `id` nuevo o existente).
    public func save(_ item: RecurringItem) async throws {
        try await recurringItemStore.save(item)
        await load()
    }

    /// Elimina un recurrente — no borra los gastos/ingresos ya registrados
    /// a partir de él.
    public func delete(_ item: RecurringItem) async throws {
        try await recurringItemStore.delete(id: item.id)
        await load()
    }

    /// Registra una ocurrencia como un gasto/ingreso normal, ya confirmado
    /// — nunca `needsReview`. Ese campo es para dato que Lana *infirió* y
    /// podría estar mal (Apple Pay, un ticket escaneado); un recurrente no
    /// infiere nada — el usuario ya escribió cada campo (monto, categoría,
    /// con qué se paga) al darlo de alta, así que no hay nada ambiguo que
    /// confirmar de nuevo. También recuerda que ya se registró este mes
    /// (`lastRegisteredMonth`), para que `registerDueItems()` no lo vuelva
    /// a postear. Repetir la llamada a propósito sigue creando otro gasto —
    /// no hay deduplicado silencioso en la acción manual.
    public func register(_ item: RecurringItem, on date: Date = Date()) async throws {
        try await store.save(Expense(
            kind: item.kind,
            amount: item.amount,
            concept: item.name,
            category: item.category,
            date: date,
            paymentMethod: item.paymentMethod))
        var updated = item
        updated.lastRegisteredMonth = Calendar.current.dateInterval(of: .month, for: date)?.start
        try await recurringItemStore.save(updated)
    }

    /// Registra automáticamente lo que ya venció este mes y no se ha
    /// registrado. Antes, "recurrente" solo agregaba un botón de un toque,
    /// lo cual, como notó el usuario, no tenía mucho chiste: si de todos
    /// modos hay que acordarse de tocarlo cada mes, no es distinto de
    /// anotarlo a mano. Se llama aparte de `onAppear()` (no cada vez que
    /// la pantalla reaparece, solo una vez por sesión desde
    /// `DashboardView`) para no mezclar "cargar la lista" con "tiene
    /// efectos secundarios en el store".
    public func registerDueItems(asOf date: Date = Date(), calendar: Calendar = .current) async {
        guard let monthStart = calendar.dateInterval(of: .month, for: date)?.start,
              let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count else { return }
        let today = calendar.component(.day, from: date)
        // Se relee directo del store, no de `items` — `items` puede estar
        // desactualizado si algo (un registro manual, otra pestaña) lo
        // cambió sin pasar por `load()` todavía, y decidir con ese dato
        // viejo podría duplicar un registro.
        guard let currentItems = try? await recurringItemStore.items() else { return }
        var registeredAny = false
        for item in currentItems {
            let effectiveDay = min(item.dayOfMonth, daysInMonth)
            guard effectiveDay <= today, item.lastRegisteredMonth != monthStart else { continue }
            if await (try? register(item, on: date)) != nil {
                registeredAny = true
            }
        }
        if registeredAny {
            await load()
        }
    }

    /// El formulario de agregar (`editing: nil`) o editar un recurrente.
    public func makeAddModel(editing item: RecurringItem? = nil) -> AddRecurringItemModel {
        AddRecurringItemModel(recurringItemStore: recurringItemStore, editing: item, cards: cards)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await recurringItemStore.items()
            cards = try await cardStore.cards()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

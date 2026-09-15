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
    /// Qué recurrentes ya se registraron en el mes actual, y cómo. Un
    /// recurrente sin entrada sigue pendiente. Se deriva de los movimientos
    /// del mes cada vez que se carga (ADR-0042).
    public private(set) var registrations: [RecurringItemID: RecurringItem.Registration] = [:]
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
    /// `DashboardView` pide el registro automático al aparecer, al refrescar
    /// y al volver a primer plano; esas llamadas pueden solaparse, y dos
    /// pasadas que leen el store antes de que cualquiera escriba registrarían
    /// el mismo recurrente dos veces.
    private var isRegisteringDueItems = false

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
    /// confirmar de nuevo.
    ///
    /// El movimiento lleva de qué recurrente salió, y eso es lo que lo marca
    /// como registrado en el mes: no se guarda ninguna marca aparte, así que
    /// borrarlo deja el recurrente pendiente otra vez (ADR-0042). Repetir la
    /// llamada a propósito sigue creando otro gasto; no hay deduplicado
    /// silencioso en la acción manual.
    public func register(_ item: RecurringItem, on date: Date = Date()) async throws {
        try await store.save(Expense(
            kind: item.kind,
            amount: item.amount,
            concept: item.name,
            category: item.category,
            subcategory: item.subcategory,
            date: date,
            paymentMethod: item.paymentMethod,
            recurringItemID: item.id))
    }

    /// Registra automáticamente lo que ya venció este mes y no se ha
    /// registrado. Antes, "recurrente" solo agregaba un botón de un toque,
    /// lo cual, como notó el usuario, no tenía mucho chiste: si de todos
    /// modos hay que acordarse de tocarlo cada mes, no es distinto de
    /// anotarlo a mano. Se llama aparte de `onAppear()` para no mezclar
    /// "cargar la lista" con "tiene efectos secundarios en el store".
    ///
    /// Pasa **una vez por mes** por cada recurrente (`lastAutoRegisteredMonth`),
    /// ya sea que lo registre o que ya estuviera registrado a mano. Si
    /// después alguien borra el movimiento, el recurrente queda pendiente
    /// pero Lana no lo vuelve a postear sola: se borró por algo, como un
    /// sueldo que se retrasó (ADR-0042).
    public func registerDueItems(asOf date: Date = Date(), calendar: Calendar = .current) async {
        guard !isRegisteringDueItems else { return }
        isRegisteringDueItems = true
        defer { isRegisteringDueItems = false }

        guard let month = calendar.dateInterval(of: .month, for: date) else { return }
        // Se relee directo del store, no de `items`/`registrations` — pueden
        // estar desactualizados si algo (un registro manual, otra pestaña) los
        // cambió sin pasar por `load()` todavía, y decidir con ese dato viejo
        // podría duplicar un registro.
        guard let currentItems = try? await recurringItemStore.items(),
              let monthExpenses = try? await store.expenses(in: month) else { return }
        var changedAny = false
        for item in currentItems {
            guard item.isDue(asOf: date, calendar: calendar),
                  !item.hasAutoRegistered(inMonthOf: date, calendar: calendar) else { continue }
            if item.registration(in: monthExpenses, forMonthOf: date, calendar: calendar) == nil {
                guard await (try? register(item, on: date)) != nil else { continue }
            }
            var updated = item
            updated.lastAutoRegisteredMonth = month.start
            try? await recurringItemStore.save(updated)
            changedAny = true
        }
        if changedAny {
            await load()
        }
    }

    /// El formulario de agregar (`editing: nil`) o editar un recurrente.
    public func makeAddModel(editing item: RecurringItem? = nil) -> AddRecurringItemModel {
        AddRecurringItemModel(recurringItemStore: recurringItemStore, store: store, editing: item, cards: cards)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await recurringItemStore.items()
            cards = try await cardStore.cards()
            let now = Date()
            if let month = Calendar.current.dateInterval(of: .month, for: now) {
                let monthExpenses = try await store.expenses(in: month)
                registrations = Dictionary(uniqueKeysWithValues: items.compactMap { item in
                    item.registration(in: monthExpenses, forMonthOf: now).map { (item.id, $0) }
                })
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

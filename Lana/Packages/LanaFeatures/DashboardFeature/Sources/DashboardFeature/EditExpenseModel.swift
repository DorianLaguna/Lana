import Foundation
import LanaCore
import Observation

/// El formulario de un gasto/ingreso, en sus dos modos (`Mode`): editar uno
/// ya guardado, o registrar uno nuevo a mano (ADR-0035). Es el mismo modelo
/// porque son los mismos campos — duplicarlo habría dejado dos formularios
/// que se desincronizan cada vez que se agrega uno.
///
/// Editando, guardar aquí emite una corrección
/// (Docs/CLAUDE.md — "editar emite una corrección; nada se muta en su
/// lugar"), no una transacción nueva: se llama `store.save(_:)` con el
/// mismo `id`. Si la categoría cambió respecto a la original, se registra
/// como aprendizaje (ADR-0012) — la misma regla que ya corre al confirmar
/// una captura nueva, pero antes no había ninguna forma de llegar aquí
/// desde un gasto ya guardado: Ajustes prometía "Lana aprende de tus
/// correcciones" sin que hubiera nada que corregir después de capturar.
@MainActor
@Observable
public final class EditExpenseModel: Identifiable {
    /// Si este formulario está creando una transacción desde cero o
    /// corrigiendo una ya guardada (ADR-0035). El modelo es el mismo porque
    /// los campos son los mismos; lo único que cambia es el título, que no
    /// haya "Borrar" y que no se pueda guardar un registro en blanco.
    public enum Mode: Equatable, Sendable {
        case creating
        case editing
    }

    /// Identidad de la instancia — para presentar con `.sheet(item:)`, no
    /// tiene relación con `Expense.ID`.
    public let id = UUID()
    /// Desde dónde se abrió este formulario — ver `Mode`.
    public let mode: Mode
    /// Al voltear entre gasto e ingreso, la categoría salta al catálogo que
    /// corresponde: son listas distintas (ADR-0040) y dejar "comida" pegada a
    /// un ingreso guardaría una categoría que su propio picker no puede
    /// mostrar.
    public var kind: Expense.Kind {
        didSet {
            guard kind != oldValue else { return }
            category = Self.defaultCategory(for: kind)
            // La subcategoría es vocabulario de su categoría; con el catálogo
            // cambiado ya no significa lo mismo.
            subcategory = ""
        }
    }

    public var amount: Decimal
    public var concept: String
    public var category: String
    public var subcategory: String
    public var date: Date
    /// Con qué se pagó. No opcional aunque `Expense.paymentMethod` sí lo
    /// sea: `ExpenseAdded.paymentMethod` no admite `nil`, así que todo gasto
    /// guardado ya trae uno — el `nil` solo existe para los ingresos, y ahí
    /// el picker ni se muestra. Ofrecer un "sin especificar" habría sido
    /// mentira en los dos modos: al crear se guarda como efectivo
    /// (`CoreDataExpenseStore.makeEvent`), y al editar `nil` significa "no
    /// cambies esto" en `ExpenseCorrected`, así que elegirlo no haría nada.
    public var paymentMethod: PaymentMethod
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false
    /// Las subcategorías ya usadas alguna vez, por categoría — para el
    /// dropdown de `EditExpenseView` (mismo patrón que `EntryModel`).
    public private(set) var allSubcategories: [String: [String]] = [:]
    /// Las tarjetas reales del usuario, para el picker de método de pago —
    /// sin esto no había forma de decir con qué tarjeta se pagó un gasto que
    /// se registra a mano, ni de corregir la que Apple Pay resolvió mal.
    public private(set) var cards: [Card] = []
    /// `cards` vacío no distingue "el usuario no tiene tarjetas" de
    /// "`onAppear()` todavía no corre" — sin esto, `orphanedCardPaymentMethod`
    /// daba por eliminada toda tarjeta en el instante previo a la carga.
    private var didLoadCards = false

    /// A qué lista compartida pertenece el gasto. `nil` = personal. Cambiarlo
    /// mueve el gasto de un lado a otro sin borrarlo ni recapturarlo
    /// (ADR-0027) — pedido explícito del usuario ("con unos gastos que se
    /// hagan puede ser que después lo quiera hacer como compartido").
    public var sharedListID: SharedListID?
    /// Quién pagó, dentro de la lista elegida. Se prellena con tu propia
    /// identidad (ADR-0022) al elegir una lista, que es el caso común.
    public var payer: ParticipantID?
    /// Las listas compartidas del usuario, para el picker.
    public private(set) var sharedLists: [SharedList] = []

    private let expense: Expense
    private let originalCategory: String
    private let store: any ExpenseStore
    private let vocabularyStore: any CorrectionVocabularyStore
    private let cardStore: any CardStore
    private let sharedListStore: any SharedListStore
    private var viewerIdentities: [SharedListID: ParticipantID] = [:]
    /// `nil` hasta que el usuario toca el picker de división — así el gasto
    /// conserva su regla original mientras no se decida cambiarla.
    private var chosenSplitKind: SplitRuleKind?

    /// - Parameters:
    ///   - expense: el gasto/ingreso a editar.
    ///   - store: dónde se guarda la corrección.
    ///   - vocabularyStore: dónde se registra un cambio de categoría.
    ///   - cardStore: de dónde se leen las tarjetas reales, para el picker
    ///     de método de pago.
    ///   - sharedListStore: de dónde salen las listas compartidas, para
    ///     poder mover el gasto a una (o sacarlo de ella) sin recapturarlo.
    public convenience init(
        expense: Expense,
        store: any ExpenseStore,
        vocabularyStore: any CorrectionVocabularyStore,
        cardStore: any CardStore,
        sharedListStore: any SharedListStore) {
        self.init(
            expense: expense,
            mode: .editing,
            store: store,
            vocabularyStore: vocabularyStore,
            cardStore: cardStore,
            sharedListStore: sharedListStore)
    }

    /// El formulario en blanco para registrar algo a mano (ADR-0035) — la
    /// salida cuando dictar no es opción o el parser on-device no está
    /// disponible. No pasa por el parser, así que nada aquí es una
    /// suposición: entra sin `needsReview`.
    ///
    /// `save()` no distingue crear de corregir — `ExpenseStore` decide una u
    /// otra según si ya existe un evento raíz con ese `id`, y este `Expense`
    /// nace con uno nuevo, así que se guarda como alta.
    ///
    /// - Parameters:
    ///   - date: con qué fecha arranca el formulario. Quien lo abre decide:
    ///     el Dashboard siembra un día del mes que se está viendo, para que
    ///     lo recién creado no caiga fuera de la pantalla donde se creó.
    ///   - currency: la moneda del monto. `.mxn` por default, igual que
    ///     `DraftTransaction`.
    public convenience init(
        newExpenseOn date: Date,
        currency: Currency = .mxn,
        store: any ExpenseStore,
        vocabularyStore: any CorrectionVocabularyStore,
        cardStore: any CardStore,
        sharedListStore: any SharedListStore) {
        self.init(
            expense: Expense(
                kind: .expense,
                amount: Money(amount: 0, currency: currency),
                concept: "",
                date: date,
                paymentMethod: .cash),
            mode: .creating,
            store: store,
            vocabularyStore: vocabularyStore,
            cardStore: cardStore,
            sharedListStore: sharedListStore)
    }

    private init(
        expense: Expense,
        mode: Mode,
        store: any ExpenseStore,
        vocabularyStore: any CorrectionVocabularyStore,
        cardStore: any CardStore,
        sharedListStore: any SharedListStore) {
        self.expense = expense
        self.mode = mode
        self.store = store
        self.vocabularyStore = vocabularyStore
        self.cardStore = cardStore
        self.sharedListStore = sharedListStore
        sharedListID = expense.sharedListID
        payer = expense.payer
        kind = expense.kind
        amount = expense.amount.amount
        concept = expense.concept
        category = expense.category ?? Self.defaultCategory(for: expense.kind)
        originalCategory = expense.category ?? Self.defaultCategory(for: expense.kind)
        subcategory = expense.subcategory ?? ""
        date = expense.date
        paymentMethod = expense.paymentMethod ?? .cash
    }

    /// Con qué categoría abre un formulario según su tipo: "otro" del catálogo
    /// que le toca (ADR-0040).
    static func defaultCategory(for kind: Expense.Kind) -> String {
        switch kind {
        case .expense: SuggestedCategory.otro.rawValue
        case .income: IncomeCategory.otro.rawValue
        }
    }

    /// `false` mientras el formulario nuevo siga en blanco — guardar un
    /// registro de $0 sin concepto no rescata nada, solo mete ruido en el
    /// mes y una entrada vacía en el vocabulario (ver `save()`). No es el
    /// caso que cubre "guardar nunca se bloquea" (Docs/CLAUDE.md), que es
    /// sobre un parseo ambiguo que sí trae información que vale la pena.
    public var canSave: Bool {
        mode == .editing || (amount > 0 && !concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// El método de pago vigente, cuando apunta a una tarjeta que ya no
    /// existe — se dio de baja después de capturar el gasto. Sin esto el
    /// picker se queda con una selección que no calza con ningún tag y no
    /// marca nada, así que la forma de pago del gasto se vuelve invisible;
    /// mismo problema y misma salida que `selectableSplitKinds` con una
    /// regla de split que la lista ya no resuelve.
    public var orphanedCardPaymentMethod: PaymentMethod? {
        guard didLoadCards else { return nil }
        let cardID: CardID? = switch paymentMethod {
        case let .debit(cardID), let .credit(cardID): cardID
        case .cash, .transfer: nil
        }
        guard let cardID, !cards.contains(where: { $0.id == cardID }) else { return nil }
        return paymentMethod
    }

    /// Carga las subcategorías ya usadas, para el dropdown — rango amplio
    /// (2 años), filtrado y deduplicado por categoría del lado del
    /// cliente, mismo criterio que `EntryModel.onAppear()`.
    public func onAppear() async {
        guard let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) else { return }
        guard let expenses = try? await store.expenses(in: DateInterval(start: start, end: Date())) else { return }
        var bySubcategory: [String: Set<String>] = [:]
        for expense in expenses {
            guard let category = expense.category, let subcategory = expense.subcategory, !subcategory.isEmpty else {
                continue
            }
            bySubcategory[category, default: []].insert(subcategory)
        }
        allSubcategories = bySubcategory.mapValues { $0.sorted() }

        cards = await (try? cardStore.cards()) ?? []
        didLoadCards = true
        sharedLists = await (try? sharedListStore.lists()) ?? []
        viewerIdentities = await DashboardModel.loadViewerIdentities(
            for: sharedLists.map(\.id),
            from: sharedListStore)
    }

    /// Se llama al elegir una lista en el picker: prellena el pagador con tu
    /// propia identidad en esa lista, que es el caso común. No toca nada si
    /// el gasto ya tenía un pagador válido dentro de la lista elegida.
    public func sharedListChanged() {
        // La regla elegida era de la lista anterior — no se arrastra.
        chosenSplitKind = nil
        guard let sharedListID, let list = sharedLists.first(where: { $0.id == sharedListID }) else {
            payer = nil
            return
        }
        if let payer, list.participants.contains(where: { $0.id == payer }) {
            return
        }
        payer = viewerIdentities[sharedListID] ?? list.participants.first?.id
    }

    /// El roster de la lista elegida, para el picker de pagador. Vacío si el
    /// gasto es personal.
    public var participantsOfSelectedList: [Participant] {
        guard let sharedListID else { return [] }
        return sharedLists.first { $0.id == sharedListID }?.participants ?? []
    }

    /// La regla con la que va a quedar dividido el gasto. Si el usuario
    /// eligió una en el picker, esa manda; si no, la que ya tenía (si sigue
    /// en la misma lista) o la preferida de la lista nueva. `nil` si es
    /// personal.
    public var effectiveSplit: SplitRule? {
        guard let sharedListID, let list = sharedLists.first(where: { $0.id == sharedListID }) else { return nil }
        if let chosenSplitKind, let resolved = chosenSplitKind.resolve(in: list) {
            return resolved
        }
        return expense.sharedListID == sharedListID ? expense.split : list.preferredSplit
    }

    /// Las reglas que se pueden elegir aquí: solo las que la lista resuelve
    /// sola con lo que ya sabe (ADR-0030). `.percentage`/`.exactAmounts`
    /// piden un número por participante y se capturan en el formulario
    /// completo de Compartido, no en este editor que Tarjetas también usa.
    public var selectableSplitKinds: [SplitRuleKind] {
        guard let sharedListID, let list = sharedLists.first(where: { $0.id == sharedListID }) else { return [] }
        var kinds = SplitRuleKind.resolvable(in: list)
        // La regla que el gasto ya trae congelada (ADR-0007) puede ser una que
        // la lista no resuelve sola — `.percentage`/`.exactAmounts` se
        // capturaron en el formulario completo de Compartido. Sin ella entre
        // las opciones, el Picker queda con una selección que no calza con
        // ningún tag: no marca nada y la regla vigente se vuelve invisible.
        // Se puede ver y conservar; volver a elegirla desde cero sigue siendo
        // cosa del formulario completo, que sí pide los números.
        if let current = effectiveSplit.map(SplitRuleKind.init), !kinds.contains(current) {
            kinds.insert(current, at: 0)
        }
        return kinds
    }

    /// La opción marcada en el picker. Arranca en la del gasto y solo cambia
    /// si el usuario la toca.
    public var selectedSplitKind: SplitRuleKind? {
        get { effectiveSplit.map(SplitRuleKind.init) }
        set { chosenSplitKind = newValue }
    }

    /// El desglose de cuánto le toca a cada quien con el monto y la regla
    /// vigentes del formulario — no los guardados (ADR-0029). Así editar el
    /// monto actualiza el desglose antes de guardar, en vez de mostrar el
    /// reparto viejo.
    public var splitShares: [SplitShare] {
        guard let sharedListID, let effectiveSplit else { return [] }
        let preview = Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: expense.amount.currency),
            concept: concept,
            date: date,
            sharedListID: sharedListID,
            payer: payer,
            split: effectiveSplit)
        return preview.splitShares() ?? []
    }

    /// Cuánto de este gasto es tuyo de verdad — lo que el Dashboard suma.
    public var myShare: Money? {
        guard let sharedListID, let viewerID = viewerIdentities[sharedListID] else { return nil }
        return splitShares.first { $0.participant == viewerID }?.amount
    }

    /// Muestra "Yo" en lugar del nombre propio, igual que en la pantalla de
    /// la lista compartida (ADR-0028) — la misma regla, en
    /// `SharedList.displayName(for:viewer:)`.
    public func displayName(for id: ParticipantID) -> String {
        guard let sharedListID, let list = sharedLists.first(where: { $0.id == sharedListID }) else {
            return "Alguien"
        }
        return list.displayName(for: id, viewer: viewerIdentities[sharedListID])
    }

    /// Intenta guardar. `true` si quedó guardado — la vista decide qué
    /// hacer con eso (cerrar la hoja).
    public func save() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        // Sin concepto no hay nada que aprender: `record(term:)` no filtra
        // vacíos, así que un formulario sin concepto dejaba una entrada en
        // blanco en Ajustes y la inyectaba al prompt del parser (ADR-0012).
        let term = concept.trimmingCharacters(in: .whitespacesAndNewlines)
        if kind == .expense, category != originalCategory, !term.isEmpty {
            await vocabularyStore.record(term: term, category: category)
        }
        var updated = expense
        updated.kind = kind
        updated.amount = Money(amount: amount, currency: expense.amount.currency)
        updated.concept = concept
        // Los ingresos también se categorizan (ADR-0040), con su propio
        // catálogo — lo que cambia entre gasto e ingreso es cuál lista se usa,
        // no si hay categoría.
        updated.category = category
        updated.subcategory = subcategory.isEmpty ? nil : subcategory
        updated.date = date
        // Mismo criterio que la categoría de arriba: solo los gastos lo
        // llevan. En un ingreso, `nil` en la corrección significa "no
        // cambies esto" (`ExpenseCorrected`), así que no le inventa uno.
        updated.paymentMethod = kind == .expense ? paymentMethod : nil
        // Mover el gasto entre personal y una lista compartida (ADR-0027).
        // El split se toma de la lista (`preferredSplit`: proporcional si
        // tiene los ingresos capturados, si no partes iguales) — ajustar la
        // división gasto por gasto se hace desde la lista misma, que tiene
        // la UI completa de las 5 reglas; duplicarla aquí metería conceptos
        // de "compartido" en el editor que Cards también usa.
        updated.sharedListID = sharedListID
        updated.payer = sharedListID == nil ? nil : payer
        // Exactamente lo que el desglose venía mostrando — una sola fuente,
        // así lo que se ve antes de guardar es lo que se guarda.
        updated.split = effectiveSplit
        // Abrir esto desde la bandeja "por revisar" y guardar ES la
        // revisión — antes se quedaba marcado igual, así que tocarlo no
        // hacía nada visible.
        updated.needsReview = false
        do {
            try await store.save(updated)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Borra el gasto/ingreso — emite una anulación, no lo mueve de la
    /// vista sin más (Docs/CLAUDE.md → "los eventos son inmutables;
    /// borrar emite una anulación"). `true` si quedó borrado.
    public func delete() async -> Bool {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.delete(id: expense.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

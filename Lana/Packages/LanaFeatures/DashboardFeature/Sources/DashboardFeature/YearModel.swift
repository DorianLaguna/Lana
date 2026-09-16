import Foundation
import LanaCore
import Observation

/// Toda la lógica y el estado de la vista anual: la serie de doce meses, los
/// extremos, el promedio, los desgloses del año y las dos comparaciones. La
/// vista no decide nada — solo refleja estas propiedades
/// (Docs/ARCHITECTURE.md).
///
/// Vive en `DashboardFeature` y no en un paquete propio porque reusa tal cual
/// `CategoryBreakdownChart`, `CategoryDetailView` y `PaymentMethodDetailView`,
/// que ya están aquí; toda la aritmética, en cambio, vive en `LanaCore`
/// (`AnnualStatistics`), donde también la puede leer el análisis con IA.
@MainActor
@Observable
public final class YearModel: ExpenseProviding {
    /// El año que se está viendo.
    public private(set) var year: Int
    /// Los movimientos del año visto — de aquí derivan los drill-downs, en
    /// vivo, sin una segunda copia (ver el comment de `CategoryDetailModel`).
    public private(set) var expenses: [Expense] = []
    /// `true` mientras se está cargando el año.
    public private(set) var isLoading = false
    /// El último error, si algo falló al cargar.
    public private(set) var errorMessage: String?
    /// Qué participante es "yo" en cada lista compartida (ADR-0022), cacheado
    /// tras cargar para no volver al store en cada suma.
    public private(set) var viewerIdentities: [SharedListID: ParticipantID] = [:]
    /// Las tarjetas guardadas, para nombrar la forma de pago de cada
    /// movimiento en los drill-downs (`ExpenseProviding`).
    public private(set) var cards: [Card] = []
    /// Ver `ExpenseProviding.hasLoadedCards`.
    private(set) var hasLoadedCards = false
    /// Las estadísticas del año. Se recalculan al cargar, nunca se persisten
    /// (ADR-0005).
    public private(set) var statistics: AnnualStatistics

    /// Los movimientos de los veinticuatro meses cargados — el año visto y el
    /// anterior. No es para mostrarse: solo alimenta las dos comparaciones,
    /// que necesitan meses de fuera del año.
    private var loadedExpenses: [Expense] = []
    /// Si la pantalla ya se abrió alguna vez — ver `refreshIfLoaded()`.
    private var hasLoaded = false

    private let store: any ExpenseStore
    private let cardStore: any CardStore
    private let sharedListStore: any SharedListStore
    private let referenceDate: Date
    /// No `private` — lo pide `ExpenseProviding`, para que los drill-downs
    /// agrupen por día con el mismo calendario y no con el de la máquina.
    let calendar: Calendar

    /// - Parameters:
    ///   - store: de dónde se leen las transacciones.
    ///   - cardStore: de dónde se leen las tarjetas, para el drill-down de
    ///     "Por forma de pago".
    ///   - sharedListStore: de dónde se lee qué participante es "yo", para
    ///     sumar la parte real de un gasto compartido.
    ///   - referenceDate: qué día es "hoy". Decide qué año se abre y cuántos
    ///     meses cuentan para el promedio.
    public init(
        store: any ExpenseStore,
        cardStore: any CardStore,
        sharedListStore: any SharedListStore,
        referenceDate: Date = Date(),
        calendar: Calendar = .current) {
        self.store = store
        self.cardStore = cardStore
        self.sharedListStore = sharedListStore
        self.referenceDate = referenceDate
        self.calendar = calendar
        let year = calendar.component(.year, from: referenceDate)
        self.year = year
        statistics = AnnualStatistics(
            year: year,
            expenses: [],
            calendar: calendar,
            referenceDate: referenceDate)
    }

    /// Carga el año vigente. Se llama cuando la pantalla aparece.
    public func onAppear() async {
        hasLoaded = true
        await load()
    }

    /// Refresca solo si esta pantalla ya se abrió alguna vez.
    ///
    /// La usa el refresco central de la app (ADR-0032) tras capturar un gasto.
    /// Sin la guarda, cada captura pagaría la carga de veinticuatro meses
    /// aunque el usuario nunca haya entrado al año — y esa carga decodifica el
    /// log completo de eventos.
    public func refreshIfLoaded() async {
        guard hasLoaded else { return }
        await load()
    }

    /// El año anterior.
    public func goToPreviousYear() async {
        year -= 1
        await load()
    }

    /// El año siguiente.
    public func goToNextYear() async {
        year += 1
        await load()
    }

    /// Carga de una sola vez el año visto **y el anterior**.
    ///
    /// Veinticuatro meses en una llamada, no dos llamadas ni doce: las dos
    /// comparaciones necesitan meses de fuera del año, y traerlos aparte sería
    /// leer el store dos veces para el mismo dato. Cargar el rango ancho
    /// tampoco cuesta más que cargar un mes —`CoreDataExpenseStore.expenses(in:)`
    /// decodifica el log completo y filtra en memoria pase lo que pase.
    private func load() async {
        guard let range = loadRange() else { return }
        isLoading = true
        errorMessage = nil
        do {
            loadedExpenses = try await store.expenses(in: range)
            viewerIdentities = await DashboardModel.loadViewerIdentities(
                for: loadedExpenses,
                from: sharedListStore)
        } catch {
            errorMessage = error.localizedDescription
            loadedExpenses = []
            viewerIdentities = [:]
        }
        expenses = loadedExpenses.filter { calendar.component(.year, from: $0.date) == year }
        if let loadedCards = try? await cardStore.cards() {
            cards = loadedCards
            hasLoadedCards = true
        }
        statistics = AnnualStatistics(
            year: year,
            expenses: expenses,
            viewerIdentities: viewerIdentities,
            calendar: calendar,
            referenceDate: referenceDate)
        isLoading = false
    }

    /// Del 1 de enero del año anterior al último instante del año visto.
    ///
    /// El `-1` segundo al final es el mismo ajuste que hace `DashboardModel`:
    /// `DateInterval.contains` incluye los dos extremos y el `end` de un año
    /// es la medianoche del siguiente, así que sin esto un gasto justo a esa
    /// medianoche contaría en dos años a la vez.
    private func loadRange() -> DateInterval? {
        guard let start = calendar.date(from: DateComponents(year: year - 1, month: 1, day: 1)),
              let endExclusive = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return nil }
        return DateInterval(start: start, end: endExclusive.addingTimeInterval(-1))
    }

    /// El mes más reciente del año visto que sí tuvo movimientos.
    ///
    /// Es contra este mes que se hacen las dos comparaciones: en el año en
    /// curso suele ser el mes actual, y en un año pasado es diciembre o el
    /// último mes en que se registró algo. Comparar contra un mes vacío no
    /// diría nada.
    public var latestActiveMonth: Date? {
        statistics.currencies
            .flatMap { statistics.monthlyPoints(in: $0) }
            .filter(\.hasActivity)
            .map(\.month)
            .max()
    }

    /// El mes más reciente con movimientos contra el mes inmediatamente
    /// anterior — que puede caer en el año pasado, y por eso se cargan
    /// veinticuatro meses. `nil` si el año no tiene ningún movimiento.
    public var comparisonWithPreviousMonth: PeriodComparison? {
        guard let current = latestActiveMonth,
              let previous = calendar.date(byAdding: .month, value: -1, to: current)
        else { return nil }
        return comparison(current: current, previous: previous)
    }

    /// El mes más reciente con movimientos contra el mismo mes del año pasado.
    public var comparisonWithSameMonthLastYear: PeriodComparison? {
        guard let current = latestActiveMonth,
              let previous = calendar.date(byAdding: .year, value: -1, to: current)
        else { return nil }
        return comparison(current: current, previous: previous)
    }

    private func comparison(current: Date, previous: Date) -> PeriodComparison {
        PeriodComparison(
            current: PeriodStatistics(
                expenses: expenses(inMonthOf: current),
                viewerIdentities: viewerIdentities),
            previous: PeriodStatistics(
                expenses: expenses(inMonthOf: previous),
                viewerIdentities: viewerIdentities))
    }

    private func expenses(inMonthOf date: Date) -> [Expense] {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
        return loadedExpenses.filter { month.start <= $0.date && $0.date < month.end }
    }

    /// El drill-down de una categoría, sobre el año completo — el mismo que ya
    /// existe para el mes, derivando de este modelo en vez del Dashboard.
    public func makeCategoryDetailModel(for category: String) -> CategoryDetailModel {
        CategoryDetailModel(category: category, source: self)
    }

    /// El drill-down de una forma de pago, sobre el año completo.
    public func makePaymentMethodDetailModel(for label: String) -> PaymentMethodDetailModel {
        PaymentMethodDetailModel(label: label, source: self, cardStore: cardStore)
    }
}

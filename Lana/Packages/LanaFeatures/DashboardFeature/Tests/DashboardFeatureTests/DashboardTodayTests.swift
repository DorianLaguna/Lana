import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("Hoy y Mes — derivados de DashboardModel")
@MainActor
struct DashboardTodayTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func expense(
        kind: Expense.Kind = .expense,
        amount: Decimal,
        concept: String = "algo",
        category: String? = "despensa",
        date: Date,
        paymentMethod: PaymentMethod? = nil) -> Expense {
        Expense(
            kind: kind,
            amount: Money(amount: amount, currency: .mxn),
            concept: concept,
            category: category,
            date: date,
            paymentMethod: paymentMethod)
    }

    private func loadedModel(_ expenses: [Expense], cards: [Card] = [], month: Date) async throws -> DashboardModel {
        let store = InMemoryExpenseStore()
        for item in expenses {
            try await store.save(item)
        }
        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(seed: cards),
            sharedListStore: InMemorySharedListStore(),
            referenceDate: month,
            calendar: calendar)
        await model.onAppear()
        return model
    }

    @Test("El ritmo reparte lo restante entre los días que faltan, contando hoy")
    func ritmoRepartido() async throws {
        let model = try await loadedModel([
            expense(kind: .income, amount: 12000, category: nil, date: date(2026, 9, 1)),
            expense(amount: 9440, date: date(2026, 9, 10))
        ], month: date(2026, 9, 15))
        let total = try #require(model.monthTotals.first)

        // 2,560 restantes entre los 16 días del 15 al 30.
        #expect(model.dailyPace(for: total, asOf: date(2026, 9, 15)) == .allowance(
            Money(amount: 160, currency: .mxn),
            untilDay: 30))
    }

    @Test("Si se gastó más de lo que entró, el ritmo dice por cuánto")
    func ritmoExcedido() async throws {
        let model = try await loadedModel([
            expense(kind: .income, amount: 1000, category: nil, date: date(2026, 9, 1)),
            expense(amount: 1250, date: date(2026, 9, 2))
        ], month: date(2026, 9, 15))
        let total = try #require(model.monthTotals.first)

        #expect(model.dailyPace(for: total, asOf: date(2026, 9, 15)) == .overspent(Money(amount: 250, currency: .mxn)))
    }

    @Test("Sin ingreso o fuera del mes en curso no hay ritmo")
    func sinRitmo() async throws {
        let model = try await loadedModel([
            expense(kind: .income, amount: 1000, category: nil, date: date(2026, 8, 1))
        ], month: date(2026, 8, 15))
        let total = try #require(model.monthTotals.first)

        #expect(model.dailyPace(for: total, asOf: date(2026, 9, 15)) == nil)
    }

    @Test("Si hoy no hubo movimientos, Hoy muestra el último día con actividad")
    func ultimoDiaConActividad() async throws {
        let model = try await loadedModel([
            expense(amount: 10, concept: "viejo", date: date(2026, 9, 3)),
            expense(amount: 20, concept: "reciente", date: date(2026, 9, 12))
        ], month: date(2026, 9, 15))

        let recent = try #require(model.recentMovements(asOf: date(2026, 9, 15)))
        #expect(!recent.isToday)
        #expect(recent.items.map(\.concept) == ["reciente"])
    }

    @Test("Hoy muestra como máximo tres movimientos")
    func maximoTres() async throws {
        let model = try await loadedModel(
            (1 ... 5).map { expense(amount: Decimal($0), date: date(2026, 9, 15, hour: 8 + $0)) },
            month: date(2026, 9, 15))

        let recent = try #require(model.recentMovements(asOf: date(2026, 9, 15, hour: 20)))
        #expect(recent.isToday)
        #expect(recent.items.count == 3)
    }

    @Test("El subtítulo nombra la categoría y la tarjeta con la que se pagó")
    func subtituloConTarjeta() throws {
        let card = try Card(alias: "Nu", lastFourDigits: "", limit: nil, cutoffDay: nil, dueDay: nil, kind: .debit)
        let item = expense(amount: 300, date: date(2026, 9, 15), paymentMethod: .debit(cardID: card.id))

        #expect(DashboardModel.subtitle(for: item, cards: [card]) == MovementSubtitle(
            text: "Despensa · Débito Nu",
            isMuted: false))
    }

    @Test("Si la tarjeta ya no existe, el subtítulo lo dice apagado")
    func subtituloTarjetaEliminada() {
        let item = expense(amount: 300, date: date(2026, 9, 15), paymentMethod: .credit(cardID: CardID()))

        #expect(DashboardModel.subtitle(for: item, cards: []) == MovementSubtitle(
            text: "Despensa · Tarjeta eliminada",
            isMuted: true))
    }

    @Test("Si las tarjetas no se pudieron leer, no se afirma que la tarjeta se borró")
    func subtituloSinTarjetasCargadas() {
        let item = expense(amount: 300, date: date(2026, 9, 15), paymentMethod: .credit(cardID: CardID()))

        #expect(DashboardModel.subtitle(for: item, cards: [], cardsAreKnown: false).isMuted == false)
    }

    @Test("Un ingreso se nombra como ingreso con su categoría")
    func subtituloIngreso() {
        let item = expense(kind: .income, amount: 6000, category: "sueldo", date: date(2026, 9, 15))

        #expect(DashboardModel.subtitle(for: item, cards: []).text == "Ingreso · sueldo")
    }

    @Test("La mezcla de pago dice qué forma pesa más y cuánto")
    func mezclaDePago() async throws {
        let model = try await loadedModel([
            expense(amount: 68, date: date(2026, 9, 2), paymentMethod: .credit(cardID: CardID())),
            expense(amount: 32, date: date(2026, 9, 3), paymentMethod: .cash)
        ], month: date(2026, 9, 15))

        #expect(model.paymentMixSummary == "68% crédito")
    }

    @Test("La cifra héroe se parte en símbolo, entero y centavos")
    func cifraHeroe() {
        let parts = MoneyDisplay.heroParts(Money(amount: Decimal(string: "2562.87") ?? 0, currency: .mxn))

        #expect(parts == MoneyDisplay.HeroParts(symbol: "$", integer: "2,562", fraction: ".87"))
    }

    @Test("Un recurrente vencido y sin registrar cuenta como pendiente")
    func recurrentePendiente() async throws {
        let recurringStore = InMemoryRecurringItemStore()
        try await recurringStore.save(RecurringItem(
            name: "Renta",
            amount: Money(amount: 9000, currency: .mxn),
            kind: .expense,
            dayOfMonth: 1))
        let model = RecurringItemsModel(
            recurringItemStore: recurringStore,
            store: InMemoryExpenseStore(),
            cardStore: InMemoryCardStore())
        await model.onAppear()

        #expect(model.pendingCount(asOf: Date(), calendar: .current) == 1)
    }
}

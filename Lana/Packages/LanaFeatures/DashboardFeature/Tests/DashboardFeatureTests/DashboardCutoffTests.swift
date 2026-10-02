import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("Hoy y Mes — la tarjeta por su corte y los sueldos esperados (ADR-0060)")
@MainActor
struct DashboardCutoffTests {
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

    private func loadedModel(
        _ expenses: [Expense],
        cards: [Card] = [],
        recurringItems: [RecurringItem] = [],
        month: Date) async throws -> DashboardModel {
        let store = InMemoryExpenseStore()
        for item in expenses {
            try await store.save(item)
        }
        let model = DashboardModel(
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(seed: cards),
            sharedListStore: InMemorySharedListStore(),
            recurringItemStore: InMemoryRecurringItemStore(seed: recurringItems),
            cardPaymentStore: InMemoryCardPaymentStore(),
            referenceDate: month,
            calendar: calendar)
        await model.onAppear()
        return model
    }

    private func bancomer() throws -> Card {
        try Card(
            alias: "Bancomer",
            lastFourDigits: "1234",
            limit: Money(amount: 30000, currency: .mxn),
            cutoffDay: 23,
            dueDay: 12,
            kind: .credit)
    }

    @Test("El 1 de octubre, Te queda parte de los dos sueldos y ya carga lo comprado tras el corte")
    func arrancaConSueldosEsperados() async throws {
        let card = try bancomer()
        let items = try [14, 30].map {
            try RecurringItem(
                name: "Sueldo",
                amount: Money(amount: 12000, currency: .mxn),
                kind: .income,
                dayOfMonth: $0)
        }
        let model = try await loadedModel([
            expense(amount: 1000, date: date(2026, 9, 20), paymentMethod: .credit(cardID: card.id)),
            expense(amount: 700, date: date(2026, 9, 26), paymentMethod: .credit(cardID: card.id))
        ], cards: [card], recurringItems: items, month: date(2026, 10, 1))

        let total = try #require(model.budgetTotals(asOf: date(2026, 10, 1)).first)

        #expect(total.income == 24000)
        #expect(total.expenses == 700)
        #expect(total.remaining == 23300)
        #expect(model
            .expectedIncomeNote(in: .mxn, asOf: date(2026, 10, 1)) == "Incluye $24,000 que esperas el 14 y el 30.")
        // Mes cuenta lo mismo; lo del calendario de octubre, todavía nada.
        #expect(model.expenses.map(\.amount.amount) == [700])
        #expect(model.calendarExpenses.isEmpty)
        #expect(model.carriedInSections.flatMap(\.items).map(\.amount.amount) == [700])
        #expect(model.cutoffNotes(in: .mxn) == [
            "Incluye $700 de compras con tarjeta de septiembre que cerraron en el corte de este mes."
        ])
    }

    @Test("El 1 de octubre, Hoy dice por tarjeta lo de septiembre que ya cuenta")
    func loQueCargaCadaTarjeta() async throws {
        let card = try bancomer()
        let nuCard = try Card(
            alias: "Nu",
            lastFourDigits: "9876",
            limit: Money(amount: 20000, currency: .mxn),
            cutoffDay: 25,
            dueDay: 5,
            kind: .credit)
        let model = try await loadedModel([
            expense(amount: 1000, date: date(2026, 9, 20), paymentMethod: .credit(cardID: card.id)),
            expense(amount: 700, date: date(2026, 9, 26), paymentMethod: .credit(cardID: card.id)),
            {
                var netflix = expense(
                    amount: 300,
                    concept: "Netflix",
                    date: date(2026, 9, 27),
                    paymentMethod: .credit(cardID: card.id))
                netflix.recurringItemID = RecurringItemID()
                return netflix
            }(),
            expense(amount: 1500, date: date(2026, 9, 28), paymentMethod: .credit(cardID: nuCard.id)),
            expense(amount: 400, date: date(2026, 9, 29), paymentMethod: .transfer)
        ], cards: [card, nuCard], month: date(2026, 10, 1))

        let carried = model.carriedInByCard()

        #expect(carried.map(\.card.alias) == ["Nu", "Bancomer"])
        #expect(carried.map(\.amount.amount) == [1500, 1000])
        // El Netflix del 27 salió de un recurrente: cuenta en el total, pero
        // aparte de lo que se decidió comprar.
        #expect(carried.map(\.purchaseCount) == [1, 1])
        #expect(carried.map(\.recurringCount) == [0, 1])
        #expect(carried.map(\.purchasesAmount) == [1500, 700])
        // Al tocar Bancomer: solo lo de después del corte del 23; la compra
        // del 20 ya contó en septiembre.
        let purchases = model.carriedInSections(for: card.id, in: .mxn, recurring: false)
        let recurring = model.carriedInSections(for: card.id, in: .mxn, recurring: true)
        #expect(purchases.flatMap(\.items).map(\.amount.amount) == [700])
        #expect(recurring.flatMap(\.items).map(\.concept) == ["Netflix"])
        #expect(model.spentShare(of: Money(amount: 1000, currency: .mxn)) == 0.4)
    }

    @Test("Un recurrente registrado sin vínculo cuenta como compra y se pregunta en Por revisar")
    func recurrenteSinVinculo() async throws {
        let card = try bancomer()
        let netflix = try RecurringItem(
            name: "Netflix",
            amount: Money(amount: 139, currency: .mxn),
            kind: .expense,
            dayOfMonth: 26)
        let model = try await loadedModel([
            expense(
                amount: 139,
                concept: "netflix",
                date: date(2026, 9, 26),
                paymentMethod: .credit(cardID: card.id)),
            expense(amount: 500, concept: "Súper", date: date(2026, 9, 30), paymentMethod: .credit(cardID: card.id))
        ], cards: [card], recurringItems: [netflix], month: date(2026, 10, 1))

        let carried = try #require(model.carriedInByCard().first)

        // No se adivina: hasta que se confirme, es una compra.
        #expect(carried.recurringCount == 0)
        #expect(carried.purchaseCount == 2)
        #expect(model.recurringLinkSuggestions.map(\.expense.concept) == ["netflix"])
    }

    @Test("Día a día cuenta los recurrentes por corte de la tarjeta con que se pagan")
    func recurrentesPorCorteEnDiaADia() async throws {
        let card = try bancomer()
        let netflix = try RecurringItem(
            name: "Netflix",
            amount: Money(amount: 139, currency: .mxn),
            kind: .expense,
            dayOfMonth: 26,
            paymentMethod: .credit(cardID: card.id))
        let gamePass = try RecurringItem(
            name: "Game pass",
            amount: Money(amount: 339, currency: .mxn),
            kind: .expense,
            dayOfMonth: 10,
            paymentMethod: .credit(cardID: card.id))
        var septNetflix = expense(
            amount: 139, concept: "Netflix", date: date(2026, 9, 26), paymentMethod: .credit(cardID: card.id))
        septNetflix.recurringItemID = netflix.id
        var octGamePass = expense(
            amount: 339, concept: "Game pass", date: date(2026, 10, 10), paymentMethod: .credit(cardID: card.id))
        octGamePass.recurringItemID = gamePass.id
        let model = try await loadedModel(
            [septNetflix, octGamePass],
            cards: [card],
            recurringItems: [netflix, gamePass],
            month: date(2026, 10, 12))

        let data = try #require(model.dailySpending(excludingRecurring: false, asOf: date(2026, 10, 12)))

        // El Netflix de septiembre, tras el corte del 23, se paga en octubre.
        #expect(data.recurringCumulative.first?.amount == 139)
        #expect(data.recurringSpent(through: 12) == 478)
        // El de octubre cae el 26, después del corte: se paga en noviembre.
        #expect(data.upcomingNextMonthRecurring.map(\.concept) == ["Netflix"])
        #expect(data.nextMonthRecurringCumulative.first?.day == 26)
        #expect(data.upcomingRecurring.isEmpty)
    }

    @Test("En septiembre, lo comprado con tarjeta después del corte sale de Mes y se dice a dónde se fue")
    func loDespuesDelCorteSeVa() async throws {
        let card = try bancomer()
        let model = try await loadedModel([
            expense(amount: 1000, date: date(2026, 9, 20), paymentMethod: .credit(cardID: card.id)),
            expense(amount: 700, date: date(2026, 9, 26), paymentMethod: .credit(cardID: card.id)),
            expense(amount: 2500, date: date(2026, 9, 27), paymentMethod: .transfer)
        ], cards: [card], month: date(2026, 9, 28))

        #expect(model.monthTotals.first?.expenses == 3500)
        #expect(model.calendarExpenses.count == 3)
        // La lista de Mes la sigue mostrando, con su etiqueta.
        #expect(model.daySections.flatMap(\.items).count == 3)
        let deferred = model.calendarExpenses.compactMap { model.deferredLabel(for: $0) }
        #expect(deferred == ["Para octubre"])
        #expect(model.cutoffNotes(in: .mxn) == ["$700 de compras con tarjeta después del corte ya cuentan en octubre."])
    }

    @Test("El último día del mes ya no hay ritmo diario: es cierre")
    func ultimoDia() async throws {
        let model = try await loadedModel([
            expense(kind: .income, amount: 24000, category: nil, date: date(2026, 9, 1)),
            expense(amount: 17439, date: date(2026, 9, 10))
        ], month: date(2026, 9, 30))
        let total = try #require(model.budgetTotals(asOf: date(2026, 9, 30)).first)

        #expect(model.isMonthClosing(asOf: date(2026, 9, 30)))
        #expect(!model.isMonthClosing(asOf: date(2026, 9, 29)))
        #expect(model.dailyPace(for: total, asOf: date(2026, 9, 30)) == nil)
    }
}

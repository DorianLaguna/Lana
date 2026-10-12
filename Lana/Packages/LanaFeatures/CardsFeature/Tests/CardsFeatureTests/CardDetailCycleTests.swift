import Foundation
import LanaCore
import Testing
@testable import CardsFeature

@Suite("CardDetailModel — moverse entre cortes")
@MainActor
struct CardDetailCycleTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // swiftlint:disable:next force_unwrapping
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Con corte el 12 y "hoy" el 5 de octubre, el corte vigente es
    /// `(12 sep, 12 oct]` y el anterior `(12 ago, 12 sep]`.
    private var today: Date { date(2026, 10, 5) }

    private func creditCard() throws -> Card {
        try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 20000, currency: .mxn),
            cutoffDay: 12,
            dueDay: 20)
    }

    private func charge(
        _ amount: Decimal,
        on date: Date,
        card: Card,
        concept: String = "cargo",
        category: String = "otro") -> Expense {
        Expense(
            kind: .expense,
            amount: Money(amount: amount, currency: .mxn),
            concept: concept,
            category: category,
            date: date,
            paymentMethod: .credit(cardID: card.id))
    }

    /// Un cargo a la tarjeta es un gasto pagado con crédito — no hay un evento
    /// aparte de "cargo" (ADR-0014).
    private func chargeEvent(_ amount: Decimal, on date: Date, card: Card) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "cargo",
            category: "otro",
            date: date,
            paymentMethod: .credit(cardID: card.id)))
    }

    /// Cuatro cargos, uno por corte: octubre y septiembre caen en el vigente,
    /// agosto en el anterior y julio dos cortes atrás.
    private func loadedModel() async throws -> CardDetailModel {
        let card = try creditCard()
        let charges = [
            charge(300, on: date(2026, 10, 1), card: card, concept: "súper", category: "despensa"),
            charge(150, on: date(2026, 9, 20), card: card, concept: "café", category: "comida"),
            charge(500, on: date(2026, 8, 25), card: card, concept: "gasolina", category: "transporte"),
            charge(200, on: date(2026, 7, 20), card: card, concept: "cine", category: "diversion")
        ]

        let store = InMemoryExpenseStore()
        for expense in charges {
            try await store.save(expense)
        }
        let model = CardDetailModel(
            card: card,
            store: store,
            cardPaymentStore: InMemoryCardPaymentStore(),
            calendar: calendar)
        await model.onAppear(asOf: today)
        return model
    }

    @Test("Al abrir se ve el corte vigente")
    func alAbrirSeVeElCorteVigente() async throws {
        let model = try await loadedModel()

        #expect(model.expenses.map(\.concept) == ["café", "súper"])
    }

    @Test("Un corte atrás trae los cargos de ese corte y ninguno del vigente")
    func unCorteAtras() async throws {
        let model = try await loadedModel()

        model.goToPreviousCycle()

        #expect(model.expenses.map(\.concept) == ["gasolina"])
    }

    @Test("El desglose por categoría sigue al corte seleccionado")
    func elDesgloseSigueAlCorte() async throws {
        let model = try await loadedModel()

        model.goToPreviousCycle()

        #expect(model.categoryTotals.map(\.category) == ["transporte"])
    }

    @Test("La etiqueta dice el corte que se está viendo")
    func laEtiquetaDiceElCorte() async throws {
        let model = try await loadedModel()
        #expect(model.cycleLabel == "Corte del 12 de octubre")

        model.goToPreviousCycle()

        #expect(model.cycleLabel == "Corte del 12 de septiembre")
    }

    @Test("Los saldos no cambian al moverse a un corte anterior")
    func losSaldosNoCambian() async throws {
        let card = try creditCard()
        let store = InMemoryExpenseStore()
        try await store.save(charge(300, on: date(2026, 10, 1), card: card))
        try await store.save(charge(500, on: date(2026, 8, 25), card: card))
        let model = CardDetailModel(
            card: card,
            store: store,
            cardPaymentStore: InMemoryCardPaymentStore(seed: [
                chargeEvent(300, on: date(2026, 10, 1), card: card),
                chargeEvent(500, on: date(2026, 8, 25), card: card)
            ]),
            calendar: calendar)
        await model.onAppear(asOf: today)
        let antes = [model.totalDebt, model.statementDue, model.currentCycleAccrued]

        model.goToPreviousCycle()

        #expect([model.totalDebt, model.statementDue, model.currentCycleAccrued] == antes)
    }

    @Test("En el corte vigente no se puede ir hacia adelante")
    func enElVigenteNoHayAdelante() async throws {
        let model = try await loadedModel()

        #expect(!model.canGoToNextCycle)
    }

    @Test("Volver del corte anterior regresa al vigente")
    func volverRegresaAlVigente() async throws {
        let model = try await loadedModel()
        model.goToPreviousCycle()

        model.goToNextCycle()

        #expect(model.isViewingCurrentCycle)
    }

    @Test("No se puede ir más atrás del cargo más viejo")
    func noSePuedeIrMasAtrasDelPrimerCargo() async throws {
        let model = try await loadedModel()

        model.goToPreviousCycle()
        model.goToPreviousCycle()

        #expect(!model.canGoToPreviousCycle)
    }

    @Test("Un corte sin movimientos se puede ver si hay cargos más viejos")
    func unCorteVacioEnMedio() async throws {
        let card = try creditCard()
        let store = InMemoryExpenseStore()
        try await store.save(charge(300, on: date(2026, 10, 1), card: card))
        // Nada en el corte de septiembre; sí en el de agosto.
        try await store.save(charge(500, on: date(2026, 7, 20), card: card))
        let model = CardDetailModel(
            card: card,
            store: store,
            cardPaymentStore: InMemoryCardPaymentStore(),
            calendar: calendar)
        await model.onAppear(asOf: today)

        model.goToPreviousCycle()

        #expect(model.expenses.isEmpty)
        #expect(model.canGoToPreviousCycle)
    }

    @Test("Un cargo en la medianoche del corte sale en un solo corte")
    func unCargoEnElCorteSaleUnaVez() async throws {
        let card = try creditCard()
        let enElCorte = calendar.startOfDay(for: date(2026, 9, 12))
        let store = InMemoryExpenseStore()
        try await store.save(charge(300, on: date(2026, 10, 1), card: card))
        try await store.save(charge(99, on: enElCorte, card: card, concept: "justo en el corte"))
        let model = CardDetailModel(
            card: card,
            store: store,
            cardPaymentStore: InMemoryCardPaymentStore(),
            calendar: calendar)
        await model.onAppear(asOf: today)

        let enVigente = model.expenses.filter { $0.concept == "justo en el corte" }.count
        model.goToPreviousCycle()
        let enAnterior = model.expenses.filter { $0.concept == "justo en el corte" }.count

        #expect(enVigente + enAnterior == 1)
    }

    @Test("Refrescar conserva el corte que se estaba viendo")
    func refrescarConservaElCorte() async throws {
        let model = try await loadedModel()
        model.goToPreviousCycle()

        await model.onAppear(asOf: today)

        #expect(model.expenses.map(\.concept) == ["gasolina"])
    }

    @Test("Una tarjeta de débito no tiene corte que seleccionar")
    func debitoNoTieneCorte() async throws {
        let debito = try Card(
            alias: "Nu débito",
            lastFourDigits: "1006",
            limit: nil,
            cutoffDay: nil,
            dueDay: nil,
            kind: .debit)
        let model = CardDetailModel(
            card: debito,
            store: InMemoryExpenseStore(),
            cardPaymentStore: InMemoryCardPaymentStore(),
            calendar: calendar)

        await model.onAppear(asOf: today)

        #expect(model.cycleLabel == nil)
    }
}

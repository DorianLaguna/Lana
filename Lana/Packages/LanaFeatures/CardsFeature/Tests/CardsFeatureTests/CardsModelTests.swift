import Foundation
import LanaCore
import LanaDesign
import Testing
@testable import CardsFeature

@Suite("CardsModel")
@MainActor
struct CardsModelTests {
    private func makeCard(
        alias: String = "BBVA Oro",
        lastFourDigits: String = "4821",
        limit: Decimal = 10000,
        cutoffDay: Int = 15,
        dueDay: Int = 5) throws -> Card {
        try Card(
            alias: alias,
            lastFourDigits: lastFourDigits,
            limit: Money(amount: limit, currency: .mxn),
            cutoffDay: cutoffDay,
            dueDay: dueDay)
    }

    /// Un cargo de crédito crudo, para sembrar `InMemoryCardPaymentStore`
    /// — `CardLedger` opera sobre eventos, no sobre `Expense` ya plegado.
    private func chargeEvent(amount: Decimal, cardID: CardID, date: Date = Date()) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "súper",
            category: "despensa",
            date: date,
            paymentMethod: .credit(cardID: cardID)))
    }

    @Test("onAppear carga las tarjetas guardadas")
    func onAppearCargaLasTarjetas() async throws {
        let cardStore = InMemoryCardStore()
        let card = try makeCard()
        try await cardStore.save(card)

        let model = CardsModel(
            cardStore: cardStore,
            store: InMemoryExpenseStore(),
            cardPaymentStore: InMemoryCardPaymentStore())
        await model.onAppear()

        #expect(model.cards.map(\.id) == [card.id])
    }

    @Test("Una tarjeta sin cargos de crédito en el ciclo vigente no tiene deuda")
    func sinCargosDeCreditoNoTieneDeuda() async throws {
        let cardStore = InMemoryCardStore()
        let card = try makeCard(cutoffDay: 28)
        try await cardStore.save(card)

        let model = CardsModel(
            cardStore: cardStore,
            store: InMemoryExpenseStore(),
            cardPaymentStore: InMemoryCardPaymentStore())
        await model.onAppear()

        #expect(model.debt(for: card)?.amount == 0)
    }

    @Test("Los cargos de crédito a la tarjeta, dentro del ciclo vigente, cuentan como deuda")
    func cargosDeCreditoDentroDelCicloCuentanComoDeuda() async throws {
        let cardStore = InMemoryCardStore()
        let card = try makeCard(cutoffDay: 28)
        try await cardStore.save(card)

        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 300, currency: .mxn),
            concept: "súper",
            category: "despensa",
            date: Date(),
            paymentMethod: .credit(cardID: card.id)))
        let cardPaymentStore = InMemoryCardPaymentStore(seed: [chargeEvent(amount: 300, cardID: card.id)])

        let model = CardsModel(cardStore: cardStore, store: store, cardPaymentStore: cardPaymentStore)
        await model.onAppear()

        #expect(model.debt(for: card)?.amount == 300)
    }

    @Test("Un cargo en débito nunca cuenta como deuda de la tarjeta")
    func cargoEnDebitoNuncaCuentaComoDeuda() async throws {
        let cardStore = InMemoryCardStore()
        let card = try makeCard(cutoffDay: 28)
        try await cardStore.save(card)

        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 300, currency: .mxn),
            concept: "súper",
            category: "despensa",
            date: Date(),
            paymentMethod: .debit(cardID: card.id)))

        let model = CardsModel(cardStore: cardStore, store: store, cardPaymentStore: InMemoryCardPaymentStore())
        await model.onAppear()

        #expect(model.debt(for: card)?.amount == 0)
    }

    @Test("Borrar una tarjeta la quita de la lista")
    func borrarUnaTarjetaLaQuitaDeLaLista() async throws {
        let cardStore = InMemoryCardStore()
        let card = try makeCard()
        try await cardStore.save(card)

        let model = CardsModel(
            cardStore: cardStore,
            store: InMemoryExpenseStore(),
            cardPaymentStore: InMemoryCardPaymentStore())
        await model.onAppear()
        try await model.delete(card)

        #expect(model.cards.isEmpty)
    }
}

@Suite("CardDetailModel")
@MainActor
struct CardDetailModelTests {
    private func makeCard(cutoffDay: Int = 28) throws -> Card {
        try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: cutoffDay,
            dueDay: 5)
    }

    private func chargeEvent(amount: Decimal, cardID: CardID, date: Date = Date()) -> ExpenseEvent {
        .expenseAdded(ExpenseAdded(
            amount: Money(amount: amount, currency: .mxn),
            concept: "cargo",
            category: "otro",
            date: date,
            paymentMethod: .credit(cardID: cardID)))
    }

    @Test("Solo cuenta los cargos de crédito de esta tarjeta, dentro del ciclo vigente")
    func soloCuentaCargosDeCreditoDeEstaTarjeta() async throws {
        let card = try makeCard()
        let otherCard = try Card(
            alias: "Otra",
            lastFourDigits: "1006",
            limit: Money(amount: 5000, currency: .mxn),
            cutoffDay: 28,
            dueDay: 5)

        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 300, currency: .mxn),
            concept: "súper",
            category: "despensa",
            date: Date(),
            paymentMethod: .credit(cardID: card.id)))
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 999, currency: .mxn),
            concept: "otra tarjeta",
            category: "comida",
            date: Date(),
            paymentMethod: .credit(cardID: otherCard.id)))
        let cardPaymentStore = InMemoryCardPaymentStore(seed: [
            chargeEvent(amount: 300, cardID: card.id),
            chargeEvent(amount: 999, cardID: otherCard.id)
        ])

        let model = CardDetailModel(card: card, store: store, cardPaymentStore: cardPaymentStore)
        await model.onAppear()

        #expect(model.expenses.count == 1)
        #expect(model.totalDebt.amount == 300)
    }

    @Test("limitFraction nunca pasa de 1, aunque la deuda rebase el límite")
    func limitFractionNuncaPasaDeUno() async throws {
        let card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 100, currency: .mxn),
            cutoffDay: 28,
            dueDay: 5)

        let store = InMemoryExpenseStore()
        try await store.save(Expense(
            kind: .expense,
            amount: Money(amount: 500, currency: .mxn),
            concept: "algo caro",
            category: "otro",
            date: Date(),
            paymentMethod: .credit(cardID: card.id)))
        let cardPaymentStore = InMemoryCardPaymentStore(seed: [chargeEvent(amount: 500, cardID: card.id)])

        let model = CardDetailModel(card: card, store: store, cardPaymentStore: cardPaymentStore)
        await model.onAppear()

        #expect(model.limitFraction == 1)
    }

    @Test("Registrar un pago reduce lo que falta pagar del último estado de cuenta, no el ciclo vigente")
    func registrarUnPagoReduceLoQueFaltaPagarDelUltimoEstado() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Mexico_City"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let lastCycleCharge = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20)))

        let card = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 28,
            dueDay: 5)

        let cardPaymentStore = InMemoryCardPaymentStore(seed: [
            chargeEvent(amount: 1000, cardID: card.id, date: lastCycleCharge)
        ])
        let model = CardDetailModel(
            card: card,
            store: InMemoryExpenseStore(),
            cardPaymentStore: cardPaymentStore,
            calendar: calendar)
        await model.onAppear(asOf: now)
        #expect(model.statementDue.amount == 1000)

        let paid = await model.recordPayment(amount: 1000, date: now)

        #expect(paid)
        #expect(model.statementDue.amount == 0)
    }
}

@Suite("AddCardModel")
@MainActor
struct AddCardModelTests {
    @Test("Guardar una tarjeta válida la persiste en el store")
    func guardarUnaTarjetaValidaLaPersiste() async throws {
        let cardStore = InMemoryCardStore()
        let model = AddCardModel(cardStore: cardStore)
        model.alias = "BBVA Oro"
        model.lastFourDigits = "4821"
        model.limitAmount = 10000
        model.cutoffDay = 15
        model.dueDay = 5

        let saved = await model.save()

        #expect(saved)
        let cards = try await cardStore.cards()
        #expect(cards.count == 1)
        #expect(cards.first?.alias == "BBVA Oro")
    }

    @Test("Sin especificar, una tarjeta nueva es de crédito, con el primer color de la paleta")
    func porDefaultEsDeCreditoConElPrimerColor() async throws {
        let cardStore = InMemoryCardStore()
        let model = AddCardModel(cardStore: cardStore)
        model.alias = "BBVA Oro"
        model.limitAmount = 10000

        _ = await model.save()

        let cards = try await cardStore.cards()
        #expect(cards.first?.kind == .credit)
        #expect(cards.first?.colorHex == LanaCardColors.palette[0])
    }

    @Test("El tipo y el color elegidos se guardan tal cual")
    func elTipoYElColorElegidosSeGuardan() async throws {
        let cardStore = InMemoryCardStore()
        let model = AddCardModel(cardStore: cardStore)
        model.alias = "Nu débito"
        model.limitAmount = 5000
        model.kind = .debit
        model.colorHex = "#6C4FB3"

        _ = await model.save()

        let cards = try await cardStore.cards()
        #expect(cards.first?.kind == .debit)
        #expect(cards.first?.colorHex == "#6C4FB3")
    }

    @Test("Editar preserva el tipo y el color ya guardados")
    func editarPreservaElTipoYElColor() async throws {
        let cardStore = InMemoryCardStore()
        let existing = try Card(
            alias: "Nu débito",
            lastFourDigits: "1234",
            limit: Money(amount: 5000, currency: .mxn),
            cutoffDay: 1,
            dueDay: 1,
            kind: .debit,
            colorHex: "#6C4FB3")
        try await cardStore.save(existing)

        let model = AddCardModel(cardStore: cardStore, editing: existing)
        #expect(model.kind == .debit)
        #expect(model.colorHex == "#6C4FB3")
    }

    @Test("Guardar sin últimos 4 dígitos funciona — no son obligatorios")
    func guardarSinUltimosCuatroDigitosFunciona() async throws {
        let cardStore = InMemoryCardStore()
        let model = AddCardModel(cardStore: cardStore)
        model.alias = "Efectivo en sobre"
        model.lastFourDigits = ""
        model.limitAmount = 5000
        model.cutoffDay = 1
        model.dueDay = 1

        let saved = await model.save()

        #expect(saved)
        let cards = try await cardStore.cards()
        #expect(cards.first?.lastFourDigits == nil)
    }

    @Test("Un débito no guarda límite, corte ni fecha límite de pago aunque el usuario los haya tecleado")
    func unDebitoNoGuardaLimiteNiFechas() async throws {
        let cardStore = InMemoryCardStore()
        let model = AddCardModel(cardStore: cardStore)
        model.alias = "Nu débito"
        model.kind = .debit
        // El usuario pudo haber tecleado esto mientras el picker estaba en
        // Crédito, antes de cambiar a Débito — no debe guardarse.
        model.limitAmount = 5000
        model.cutoffDay = 20
        model.dueDay = 5

        let saved = await model.save()

        #expect(saved)
        let cards = try await cardStore.cards()
        #expect(cards.first?.limit == nil)
        #expect(cards.first?.cutoffDay == nil)
        #expect(cards.first?.dueDay == nil)
    }

    @Test("Últimos 4 dígitos inválidos no guarda y deja ver el error")
    func ultimosCuatroDigitosInvalidosNoGuarda() async throws {
        let cardStore = InMemoryCardStore()
        let model = AddCardModel(cardStore: cardStore)
        model.alias = "BBVA Oro"
        model.lastFourDigits = "12"
        model.limitAmount = 10000

        let saved = await model.save()

        #expect(!saved)
        #expect(model.errorMessage != nil)
        let cards = try await cardStore.cards()
        #expect(cards.isEmpty)
    }

    @Test("Editar una tarjeta existente conserva su id")
    func editarUnaTarjetaExistenteConservaSuId() async throws {
        let cardStore = InMemoryCardStore()
        let existing = try Card(
            alias: "BBVA Oro",
            lastFourDigits: "4821",
            limit: Money(amount: 10000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
        try await cardStore.save(existing)

        let model = AddCardModel(cardStore: cardStore, editing: existing)
        model.alias = "BBVA Platino"
        _ = await model.save()

        let cards = try await cardStore.cards()
        #expect(cards.count == 1)
        #expect(cards.first?.id == existing.id)
        #expect(cards.first?.alias == "BBVA Platino")
    }
}

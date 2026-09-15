import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("EditExpenseModel — registro manual (ADR-0035)")
@MainActor
struct EditExpenseManualEntryTests {
    private func makeCard() throws -> Card {
        try Card(
            alias: "Nu",
            lastFourDigits: "1234",
            limit: Money(amount: 20000, currency: .mxn),
            cutoffDay: 15,
            dueDay: 5)
    }

    @Test("Guardar un registro manual crea una transacción nueva, no una corrección")
    func guardarUnRegistroManualCreaUnaTransaccionNueva() async throws {
        let store = InMemoryExpenseStore()

        let model = EditExpenseModel(
            newExpenseOn: Date(timeIntervalSince1970: 1_700_000_000),
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())
        model.amount = 250
        model.concept = "Café"

        #expect(model.mode == .creating)
        #expect(await model.save())

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture))
        #expect(saved.count == 1)
        #expect(saved.first?.concept == "Café")
        #expect(saved.first?.amount == Money(amount: 250, currency: .mxn))
    }

    @Test("Lo capturado a mano no entra por revisar — lo escribió el usuario, no se adivinó")
    func loCapturadoAManoNoEntraPorRevisar() async throws {
        let store = InMemoryExpenseStore()

        let model = EditExpenseModel(
            newExpenseOn: .now,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())
        model.amount = 250
        model.concept = "Café"
        #expect(await model.save())

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first
        #expect(saved?.needsReview == false)
    }

    @Test("El método de pago elegido en el formulario llega al gasto guardado")
    func elMetodoDePagoElegidoLlegaAlGastoGuardado() async throws {
        let card = try makeCard()
        let store = InMemoryExpenseStore()

        let model = EditExpenseModel(
            newExpenseOn: .now,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(seed: [card]),
            sharedListStore: InMemorySharedListStore())
        await model.onAppear()

        // Las tarjetas reales llegan al picker.
        #expect(model.cards.map(\.id) == [card.id])
        // Y el default al crear es efectivo, igual que en `DraftTransaction`.
        #expect(model.paymentMethod == .cash)

        model.amount = 250
        model.concept = "Café"
        model.paymentMethod = .credit(cardID: card.id)
        #expect(await model.save())

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first
        #expect(saved?.paymentMethod == .credit(cardID: card.id))
    }

    @Test("Editar un gasto sin tocar el método de pago conserva el que traía")
    func editarSinTocarElMetodoDePagoConservaElQueTraia() async throws {
        let card = try makeCard()
        let store = InMemoryExpenseStore()
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            date: .now,
            paymentMethod: .credit(cardID: card.id))
        try await store.save(original)

        let model = EditExpenseModel(
            expense: original,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(seed: [card]),
            sharedListStore: InMemorySharedListStore())
        #expect(model.paymentMethod == .credit(cardID: card.id))
        model.concept = "Chocolates"
        #expect(await model.save())

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first
        #expect(saved?.paymentMethod == .credit(cardID: card.id))
    }

    @Test("A un ingreso no se le inventa método de pago, aunque el formulario tenga uno")
    func aUnIngresoNoSeLeInventaMetodoDePago() async throws {
        let store = InMemoryExpenseStore()

        let model = EditExpenseModel(
            newExpenseOn: .now,
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())
        // Arranca como gasto, así que el formulario ya trae efectivo.
        #expect(model.paymentMethod == .cash)
        model.kind = .income
        model.amount = 15000
        model.concept = "Quincena"
        #expect(await model.save())

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first
        #expect(saved?.kind == .income)
        #expect(saved?.paymentMethod == nil)
    }

    @Test("La tarjeta dada de baja sigue viéndose en el picker en vez de dejarlo en blanco")
    func laTarjetaDadaDeBajaSigueViendoseEnElPicker() async throws {
        let card = try makeCard()
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            date: .now,
            paymentMethod: .credit(cardID: card.id))

        let model = EditExpenseModel(
            expense: original,
            store: InMemoryExpenseStore(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            // La tarjeta ya no existe: se dio de baja después de capturar.
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())

        // Antes de cargar no se da nada por eliminado — si no, el picker
        // parpadeaba en "Tarjeta eliminada" mientras llegaban las tarjetas.
        #expect(model.orphanedCardPaymentMethod == nil)

        await model.onAppear()

        #expect(model.orphanedCardPaymentMethod == .credit(cardID: card.id))
    }

    @Test("Una tarjeta que sí existe no se ofrece como eliminada")
    func unaTarjetaQueSiExisteNoSeOfreceComoEliminada() async throws {
        let card = try makeCard()
        let original = Expense(
            kind: .expense,
            amount: Money(amount: 131, currency: .mxn),
            concept: "Dulces",
            category: "despensa",
            date: .now,
            paymentMethod: .credit(cardID: card.id))

        let model = EditExpenseModel(
            expense: original,
            store: InMemoryExpenseStore(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(seed: [card]),
            sharedListStore: InMemorySharedListStore())
        await model.onAppear()

        #expect(model.orphanedCardPaymentMethod == nil)
    }

    @Test("Un formulario nuevo necesita monto y concepto para poder guardarse")
    func unFormularioNuevoNecesitaMontoYConcepto() {
        let model = EditExpenseModel(
            newExpenseOn: .now,
            store: InMemoryExpenseStore(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())

        #expect(!model.canSave)

        model.amount = 250
        #expect(!model.canSave)

        // Espacios no cuentan como concepto.
        model.concept = "   "
        #expect(!model.canSave)

        model.concept = "Café"
        #expect(model.canSave)
    }

    @Test("Sin concepto no se registra nada en el vocabulario, aunque cambie la categoría")
    func sinConceptoNoSeRegistraNadaEnElVocabulario() async {
        let vocabularyStore = InMemoryCorrectionVocabularyStore()

        let model = EditExpenseModel(
            expense: Expense(
                kind: .expense,
                amount: Money(amount: 131, currency: .mxn),
                concept: "  ",
                category: "despensa",
                date: .now),
            store: InMemoryExpenseStore(),
            vocabularyStore: vocabularyStore,
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())
        model.category = "comida"
        _ = await model.save()

        let entries = await vocabularyStore.allEntries()
        #expect(entries.isEmpty)
    }

    @Test("Editar siempre se puede guardar, aunque el monto quede en cero")
    func editarSiempreSePuedeGuardar() {
        let model = EditExpenseModel(
            expense: Expense(
                kind: .expense,
                amount: Money(amount: 0, currency: .mxn),
                concept: "Dulces",
                date: .now),
            store: InMemoryExpenseStore(),
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())

        #expect(model.canSave)
    }

    @Test("Elegir una categoría al capturar a mano también alimenta el vocabulario (ADR-0012)")
    func elegirCategoriaAlCapturarAManoAlimentaElVocabulario() async {
        let vocabularyStore = InMemoryCorrectionVocabularyStore()

        let model = EditExpenseModel(
            newExpenseOn: .now,
            store: InMemoryExpenseStore(),
            vocabularyStore: vocabularyStore,
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())
        model.amount = 250
        model.concept = "Café"
        model.category = "comida"
        _ = await model.save()

        let entries = await vocabularyStore.topEntries(limit: 10)
        #expect(entries.first?.term == "Café")
        #expect(entries.first?.category == "comida")
    }
}

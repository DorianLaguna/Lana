import Foundation
import LanaCore
import Testing
@testable import DashboardFeature

@Suite("EditExpenseModel — categoría de ingreso (ADR-0040)")
@MainActor
struct EditExpenseIncomeCategoryTests {
    private func newModel(store: InMemoryExpenseStore = InMemoryExpenseStore()) -> EditExpenseModel {
        EditExpenseModel(
            newExpenseOn: Date(),
            store: store,
            vocabularyStore: InMemoryCorrectionVocabularyStore(),
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())
    }

    @Test("Un ingreso guarda su categoría, ya no la pierde")
    func unIngresoGuardaSuCategoria() async throws {
        let store = InMemoryExpenseStore()
        let model = newModel(store: store)
        model.kind = .income
        model.concept = "quincena"
        model.amount = 18000
        model.category = IncomeCategory.sueldo.rawValue

        _ = await model.save()

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first
        #expect(saved?.kind == .income)
        #expect(saved?.category == "sueldo")
    }

    @Test("Cambiar de gasto a ingreso salta de catálogo, no arrastra la categoría de gasto")
    func cambiarDeGastoAIngresoSaltaDeCatalogo() {
        let model = newModel()
        model.category = SuggestedCategory.comida.rawValue

        model.kind = .income

        // Sin esto se guardaría un ingreso con categoría "comida", que su
        // propio picker no puede ni mostrar.
        #expect(model.category == IncomeCategory.otro.rawValue)
        #expect(IncomeCategory(rawValue: model.category) != nil)
    }

    @Test("Volver de ingreso a gasto regresa al catálogo de gastos")
    func volverAGastoRegresaAlCatalogoDeGastos() {
        let model = newModel()
        model.kind = .income
        model.category = IncomeCategory.sueldo.rawValue

        model.kind = .expense

        #expect(SuggestedCategory(rawValue: model.category) != nil)
    }

    @Test("Cambiar de tipo también limpia la subcategoría — ya no significa lo mismo")
    func cambiarDeTipoLimpiaLaSubcategoria() {
        let model = newModel()
        model.subcategory = "gasolina"

        model.kind = .income

        #expect(model.subcategory.isEmpty)
    }

    @Test("Un ingreso sigue sin método de pago")
    func unIngresoSigueSinMetodoDePago() async throws {
        let store = InMemoryExpenseStore()
        let model = newModel(store: store)
        model.kind = .income
        model.concept = "quincena"
        model.amount = 18000

        _ = await model.save()

        let saved = try await store.expenses(in: DateInterval(start: .distantPast, end: .distantFuture)).first
        #expect(saved?.paymentMethod == nil)
    }

    @Test("Corregir un ingreso no ensucia el vocabulario del parser")
    func corregirUnIngresoNoEnsuciaElVocabulario() async {
        // El parser no clasifica ingresos (ADR-0040), así que meter sus
        // términos al vocabulario solo contaminaría el prompt de los gastos
        // (ADR-0012).
        let vocabulary = InMemoryCorrectionVocabularyStore()
        let model = EditExpenseModel(
            newExpenseOn: Date(),
            store: InMemoryExpenseStore(),
            vocabularyStore: vocabulary,
            cardStore: InMemoryCardStore(),
            sharedListStore: InMemorySharedListStore())
        model.kind = .income
        model.concept = "quincena"
        model.amount = 18000
        model.category = IncomeCategory.sueldo.rawValue

        _ = await model.save()

        #expect(await vocabulary.allEntries().isEmpty)
    }
}

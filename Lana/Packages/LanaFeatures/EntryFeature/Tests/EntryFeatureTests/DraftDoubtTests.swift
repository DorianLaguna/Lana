import Foundation
import LanaCore
import Testing
@testable import EntryFeature

@Suite("Dudas de un borrador")
struct DraftDoubtTests {
    @Test("Un borrador completo no tiene dudas")
    func sinDudas() {
        let draft = DraftTransaction(amount: 300, concept: "súper", category: "despensa")

        #expect(draft.doubts.isEmpty)
    }

    @Test("Sin monto, sin concepto y sin categoría, cada falta es su propio chip")
    func faltasConcretas() {
        let draft = DraftTransaction(amount: 0, concept: "  ", category: "")

        #expect(draft.doubts == [.amount, .concept, .category])
    }

    @Test("Un ingreso no pide categoría de gasto")
    func ingresoSinCategoriaDeGasto() {
        let draft = DraftTransaction(kind: .income, amount: 6000, concept: "quincena")

        #expect(draft.doubts.isEmpty)
    }

    @Test("Si el parser dudó pero no falta ningún campo, se dice una sola vez")
    func dudaGenerica() {
        let draft = DraftTransaction(
            amount: 300,
            concept: "súper",
            category: "despensa",
            needsReview: true)

        #expect(draft.doubts == [.uncertain])
    }

    @Test("Con una falta concreta, no se repite la duda genérica")
    func sinDudaGenericaRedundante() {
        let draft = DraftTransaction(amount: 0, concept: "súper", category: "despensa", needsReview: true)

        #expect(draft.doubts == [.amount])
    }
}

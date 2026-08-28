import Testing
@testable import LanaCore

@Suite("SuggestedCategory")
struct SuggestedCategoryTests {
    @Test("rampIndex es único por caso — dos categorías nunca comparten índice")
    func rampIndexEsUnicoPorCaso() {
        let indices = SuggestedCategory.allCases.map(\.rampIndex)
        #expect(Set(indices).count == indices.count)
    }

    @Test("educacion se muestra con acento aunque el raw value sea ASCII")
    func educacionSeMuestraConAcento() {
        #expect(SuggestedCategory.educacion.displayName == "Educación")
        #expect(SuggestedCategory.educacion.rawValue == "educacion")
    }
}

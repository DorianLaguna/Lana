import Testing
@testable import LanaCore

@Suite("SuggestedCategory")
struct SuggestedCategoryTests {
    @Test("educacion se muestra con acento aunque el raw value sea ASCII")
    func educacionSeMuestraConAcento() {
        #expect(SuggestedCategory.educacion.displayName == "Educación")
        #expect(SuggestedCategory.educacion.rawValue == "educacion")
    }
}

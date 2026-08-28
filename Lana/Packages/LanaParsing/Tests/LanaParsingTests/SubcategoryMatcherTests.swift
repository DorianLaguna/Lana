import Testing
@testable import LanaParsing

@Suite("SubcategoryMatcher")
struct SubcategoryMatcherTests {
    let matcher = SubcategoryMatcher()

    @Test("Un nombre nuevo sin parecido se usa tal cual")
    func nombreNuevoSeUsaTalCual() {
        #expect(matcher.resolve("gasolina", existing: []) == "gasolina")
    }

    @Test("Una variante cercana resuelve al nombre existente")
    func varianteCercanaResuelveAlExistente() {
        #expect(matcher.resolve("gasolinas", existing: ["gasolina"]) == "gasolina")
    }

    @Test("Un nombre muy distinto no se confunde con uno existente")
    func nombreDistintoNoSeConfunde() {
        #expect(matcher.resolve("cafetería", existing: ["gasolina"]) == "cafetería")
    }

    @Test("'otro' y variantes nunca son subcategorías válidas", arguments: ["otro", "Otros", "  otra ", "VARIOS"])
    func otroYVariantesInvalidas(input: String) {
        #expect(matcher.resolve(input, existing: []) == nil)
    }

    @Test("Un campo vacío no es una subcategoría válida")
    func campoVacioInvalido() {
        #expect(matcher.resolve("   ", existing: ["gasolina"]) == nil)
    }
}

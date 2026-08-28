import Testing
@testable import CardsFeature

@Suite("Scaffold de CardsFeature")
struct CardsFeatureScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(CardsFeature.moduleName == "CardsFeature")
    }
}

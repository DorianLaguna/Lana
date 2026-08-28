import Testing
@testable import InsightsFeature

@Suite("Scaffold de InsightsFeature")
struct InsightsFeatureScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(InsightsFeature.moduleName == "InsightsFeature")
    }
}

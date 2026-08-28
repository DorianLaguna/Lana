import Testing
@testable import SharedFeature

@Suite("Scaffold de SharedFeature")
struct SharedFeatureScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(SharedFeature.moduleName == "SharedFeature")
    }
}

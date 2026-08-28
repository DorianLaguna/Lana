import Testing
@testable import EntryFeature

@Suite("Scaffold de EntryFeature")
struct EntryFeatureScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(EntryFeature.moduleName == "EntryFeature")
    }
}

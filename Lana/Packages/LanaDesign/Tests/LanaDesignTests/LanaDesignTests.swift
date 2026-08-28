import Testing
@testable import LanaDesign

@Suite("Scaffold de LanaDesign")
struct LanaDesignScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(LanaDesign.moduleName == "LanaDesign")
    }
}

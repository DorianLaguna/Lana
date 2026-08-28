import Testing
@testable import LanaCore

@Suite("Scaffold de LanaCore")
struct LanaCoreScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(LanaCore.moduleName == "LanaCore")
    }
}

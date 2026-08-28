import LanaCore
import Testing
@testable import LanaPersistence

@Suite("Scaffold de LanaPersistence")
struct LanaPersistenceScaffoldTests {
    @Test("El paquete se importa")
    func expuesto() {
        #expect(LanaPersistence.moduleName == "LanaPersistence")
    }

    @Test("La dependencia declarada con LanaCore resuelve")
    func dependeDeLanaCore() {
        #expect(LanaCore.moduleName == "LanaCore")
    }
}

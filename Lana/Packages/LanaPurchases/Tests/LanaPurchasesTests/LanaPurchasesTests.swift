import LanaCore
import Testing
@testable import LanaPurchases

@Suite("Scaffold de LanaPurchases")
struct LanaPurchasesScaffoldTests {
    @Test("El paquete se importa")
    func expuesto() {
        #expect(LanaPurchases.moduleName == "LanaPurchases")
    }

    @Test("La dependencia declarada con LanaCore resuelve")
    func dependeDeLanaCore() {
        #expect(LanaCore.moduleName == "LanaCore")
    }
}

import LanaCore
import Testing
@testable import LanaParsing

@Suite("Scaffold de LanaParsing")
struct LanaParsingScaffoldTests {
    @Test("El paquete se importa")
    func expuesto() {
        #expect(LanaParsing.moduleName == "LanaParsing")
    }

    @Test("La dependencia declarada con LanaCore resuelve")
    func dependeDeLanaCore() {
        #expect(LanaCore.moduleName == "LanaCore")
    }
}

import LanaCore
import Testing
@testable import LanaSpeech

@Suite("Scaffold de LanaSpeech")
struct LanaSpeechScaffoldTests {
    @Test("El paquete se importa")
    func expuesto() {
        #expect(LanaSpeech.moduleName == "LanaSpeech")
    }

    @Test("La dependencia declarada con LanaCore resuelve")
    func dependeDeLanaCore() {
        #expect(LanaCore.moduleName == "LanaCore")
    }
}

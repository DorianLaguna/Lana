import Testing
@testable import SettingsFeature

@Suite("Scaffold de SettingsFeature")
struct SettingsFeatureScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(SettingsFeature.moduleName == "SettingsFeature")
    }
}

import Testing
@testable import DashboardFeature

@Suite("Scaffold de DashboardFeature")
struct DashboardFeatureScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(DashboardFeature.moduleName == "DashboardFeature")
    }
}

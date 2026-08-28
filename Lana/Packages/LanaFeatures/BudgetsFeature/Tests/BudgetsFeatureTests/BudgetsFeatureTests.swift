import Testing
@testable import BudgetsFeature

@Suite("Scaffold de BudgetsFeature")
struct BudgetsFeatureScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(BudgetsFeature.moduleName == "BudgetsFeature")
    }
}

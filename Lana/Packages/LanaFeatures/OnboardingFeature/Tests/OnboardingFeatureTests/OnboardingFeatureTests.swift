import Testing
@testable import OnboardingFeature

@Suite("Scaffold de OnboardingFeature")
struct OnboardingFeatureScaffoldTests {
    @Test("El paquete se importa y expone su nombre de módulo")
    func expuesto() {
        #expect(OnboardingFeature.moduleName == "OnboardingFeature")
    }
}

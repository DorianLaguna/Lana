import Foundation
import Testing
@testable import LanaCore

@Suite("BudgetRulePreference")
struct BudgetRulePreferenceTests {
    /// Un `UserDefaults` propio por test, para no ensuciar los reales ni que
    /// dos tests se pisen.
    private func freshDefaults() throws -> UserDefaults {
        let suiteName = "lana.tests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: suiteName))
    }

    @Test("Arranca sin regla elegida — no se le impone un default")
    func arrancaSinReglaElegida() throws {
        let preference = try BudgetRulePreference(userDefaults: freshDefaults())
        #expect(preference.rule == nil)
    }

    @Test("Elegir una regla la persiste de inmediato")
    func elegirUnaReglaLaPersiste() throws {
        let defaults = try freshDefaults()
        BudgetRulePreference(userDefaults: defaults).setRule(.seventyTwentyTen)

        // Una instancia nueva sobre los mismos defaults: es lo que pasa al
        // relanzar la app.
        #expect(BudgetRulePreference(userDefaults: defaults).rule == .seventyTwentyTen)
    }

    @Test("Quitar la regla regresa a sin regla, no a la default")
    func quitarLaReglaRegresaASinRegla() throws {
        let defaults = try freshDefaults()
        let preference = BudgetRulePreference(userDefaults: defaults)
        preference.setRule(.fiftyThirtyTwenty)
        preference.setRule(nil)

        #expect(preference.rule == nil)
    }

    @Test("Una regla guardada que ya no existe en el catálogo se ignora")
    func unaReglaDesconocidaSeIgnora() throws {
        let defaults = try freshDefaults()
        defaults.set("reglaQueYaNoExiste", forKey: "lana.budgetRule")

        #expect(BudgetRulePreference(userDefaults: defaults).rule == nil)
    }

    @Test("Descartar la sugerencia se recuerda — no se vuelve a proponer lo mismo")
    func descartarLaSugerenciaSeRecuerda() throws {
        let defaults = try freshDefaults()
        let preference = BudgetRulePreference(userDefaults: defaults)
        #expect(preference.hasDismissedSuggestion == false)

        preference.dismissSuggestion()

        #expect(BudgetRulePreference(userDefaults: defaults).hasDismissedSuggestion)
    }
}

import Foundation
import LanaCore
import Testing
@testable import SettingsFeature

@Suite("SettingsModel")
@MainActor
struct SettingsModelTests {
    /// Un `UserDefaults` aislado por test — `.standard` es global al
    /// proceso y filtraría estado entre corridas.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "SettingsModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        // swiftlint:disable:next force_unwrapping
        return defaults!
    }

    @Test("Sin nada guardado, el tema por default es Cobalto")
    func sinNadaGuardadoTemaPorDefault() {
        let model = SettingsModel(vocabularyStore: InMemoryCorrectionVocabularyStore(), userDefaults: makeDefaults())
        #expect(model.selectedTheme == .default)
    }

    @Test("Elegir un tema lo persiste — una instancia nueva lo lee de vuelta")
    func elegirUnTemaLoPersiste() {
        let defaults = makeDefaults()
        let model = SettingsModel(vocabularyStore: InMemoryCorrectionVocabularyStore(), userDefaults: defaults)
        model.selectTheme(.nopal)

        let reloaded = SettingsModel(vocabularyStore: InMemoryCorrectionVocabularyStore(), userDefaults: defaults)
        #expect(reloaded.selectedTheme == .nopal)
    }

    @Test("onAppear carga el vocabulario ya guardado")
    func onAppearCargaElVocabulario() async {
        let vocabularyStore = InMemoryCorrectionVocabularyStore()
        await vocabularyStore.record(term: "bocina", category: "ocio")

        let model = SettingsModel(vocabularyStore: vocabularyStore, userDefaults: makeDefaults())
        await model.onAppear()

        #expect(model.vocabulary.count == 1)
        #expect(model.vocabulary.first?.term == "bocina")
    }

    @Test("Borrar un término lo quita solo a él")
    func borrarUnTerminoLoQuitaSoloAEl() async {
        let vocabularyStore = InMemoryCorrectionVocabularyStore()
        await vocabularyStore.record(term: "bocina", category: "ocio")
        await vocabularyStore.record(term: "chicles", category: "despensa")

        let model = SettingsModel(vocabularyStore: vocabularyStore, userDefaults: makeDefaults())
        await model.onAppear()
        await model.delete(term: "bocina")

        #expect(model.vocabulary.count == 1)
        #expect(model.vocabulary.first?.term == "chicles")
    }

    @Test("Borrar todo deja el vocabulario vacío")
    func borrarTodoDejaElVocabularioVacio() async {
        let vocabularyStore = InMemoryCorrectionVocabularyStore()
        await vocabularyStore.record(term: "bocina", category: "ocio")
        await vocabularyStore.record(term: "chicles", category: "despensa")

        let model = SettingsModel(vocabularyStore: vocabularyStore, userDefaults: makeDefaults())
        await model.onAppear()
        await model.deleteAll()

        #expect(model.vocabulary.isEmpty)
    }
}

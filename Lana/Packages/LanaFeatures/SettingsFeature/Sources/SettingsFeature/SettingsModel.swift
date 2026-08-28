import Foundation
import LanaCore
import LanaDesign
import Observation

/// El tema elegido y el vocabulario aprendido (Fase 6.5). El modelo decide
/// — la vista solo refleja esto y llama a estos métodos
/// (Docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class SettingsModel {
    /// El tema activo — persistido, sobrevive relanzamientos de la app.
    public private(set) var selectedTheme: LanaTheme
    /// Lo aprendido de correcciones del usuario (ADR-0012).
    public private(set) var vocabulary: [CorrectionEntry] = []
    /// `true` mientras se está cargando el vocabulario.
    public private(set) var isLoading = false

    private let vocabularyStore: any CorrectionVocabularyStore
    private let userDefaults: UserDefaults
    private static let themeDefaultsKey = "lana.selectedTheme"

    /// - Parameters:
    ///   - vocabularyStore: dónde vive lo aprendido.
    ///   - userDefaults: dónde se persiste el tema elegido.
    public init(vocabularyStore: any CorrectionVocabularyStore, userDefaults: UserDefaults = .standard) {
        self.vocabularyStore = vocabularyStore
        self.userDefaults = userDefaults
        if let rawValue = userDefaults.string(forKey: Self.themeDefaultsKey),
           let theme = LanaTheme(rawValue: rawValue) {
            selectedTheme = theme
        } else {
            selectedTheme = .default
        }
    }

    /// Carga el vocabulario aprendido. Se llama cuando la pantalla aparece.
    public func onAppear() async {
        isLoading = true
        vocabulary = await vocabularyStore.allEntries()
        isLoading = false
    }

    /// Persiste de inmediato — no hace falta un botón "Guardar" para algo
    /// tan reversible como un tema.
    public func selectTheme(_ theme: LanaTheme) {
        selectedTheme = theme
        userDefaults.set(theme.rawValue, forKey: Self.themeDefaultsKey)
    }

    /// Olvida una palabra específica.
    public func delete(term: String) async {
        await vocabularyStore.delete(term: term)
        vocabulary = await vocabularyStore.allEntries()
    }

    /// Olvida todo lo aprendido.
    public func deleteAll() async {
        await vocabularyStore.deleteAll()
        vocabulary = await vocabularyStore.allEntries()
    }
}

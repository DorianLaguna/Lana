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
    /// Estado real de sincronización con iCloud (ADR-0020) — para que el
    /// usuario sepa que su información sí está respaldada en la nube, no
    /// solo que la cuenta está activa.
    public private(set) var syncStatus: SyncStatus = .disabled
    /// Estado del permiso de micrófono y dictado (ADR-0015). Hasta ahora solo
    /// se veía dentro de la hoja de captura, y ya fallando; aquí el usuario
    /// puede consultarlo —y arreglarlo— antes de necesitarlo. `nil` cuando no
    /// hay quién lo reporte (previews, tests): entonces la fila no se muestra.
    public private(set) var speechAvailability: SpeechAvailability?

    private let vocabularyStore: any CorrectionVocabularyStore
    private let syncStatusReporting: any SyncStatusReporting
    private let speech: (any SpeechTranscribing)?
    private let userDefaults: UserDefaults
    private static let themeDefaultsKey = "lana.selectedTheme"

    /// El nombre del tema activo, tal como lo ve el usuario ("Zafiro") — la
    /// fila resumida de Apariencia lo muestra sin abrir el selector completo.
    public var selectedThemeName: String {
        selectedTheme.displayName
    }

    /// Cuántas palabras ha aprendido Lana — para el subtítulo de la fila de
    /// Aprendizaje en la pantalla principal, sin sacar la lista de su
    /// pantalla propia.
    public var learnedWordCount: Int {
        vocabulary.count
    }

    /// La versión de la app, tal como está configurada en el bundle
    /// (`MARKETING_VERSION` → `CFBundleShortVersionString`). Nunca
    /// hardcodeada: sale de la única fuente correcta. `nil` si no hay bundle
    /// con esa clave (no debería pasar en la app real).
    public var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// - Parameters:
    ///   - vocabularyStore: dónde vive lo aprendido.
    ///   - syncStatusReporting: de dónde sale el estado real de sync.
    ///   - speech: de dónde sale el estado del permiso de dictado; `nil` para
    ///     no mostrar esa fila.
    ///   - userDefaults: dónde se persiste el tema elegido.
    public init(
        vocabularyStore: any CorrectionVocabularyStore,
        syncStatusReporting: any SyncStatusReporting,
        speech: (any SpeechTranscribing)? = nil,
        userDefaults: UserDefaults = .standard) {
        self.vocabularyStore = vocabularyStore
        self.syncStatusReporting = syncStatusReporting
        self.speech = speech
        self.userDefaults = userDefaults
        if let rawValue = userDefaults.string(forKey: Self.themeDefaultsKey),
           let theme = LanaTheme(rawValue: rawValue) {
            selectedTheme = theme
        } else {
            selectedTheme = .default
        }
    }

    /// Carga el vocabulario aprendido y arranca a escuchar el sync real. Se
    /// llama cuando la pantalla aparece.
    ///
    /// Consulta el permiso de dictado, nunca lo pide: pedirlo es cosa del
    /// micrófono, la primera vez que se toca (ADR-0015). Todo lo que no sea el
    /// stream de sync se resuelve ANTES de entrar a ese `for await`, que no
    /// termina nunca.
    public func onAppear() async {
        isLoading = true
        vocabulary = await vocabularyStore.allEntries()
        isLoading = false
        speechAvailability = await speech?.availability
        for await status in syncStatusReporting.statusUpdates() {
            syncStatus = status
        }
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

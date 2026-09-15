import LanaCore
import LanaDesign
import SwiftUI

/// "iCloud": informa que los datos de la app se guardan y sincronizan con la
/// cuenta de iCloud YA configurada en el dispositivo (ADR-0020). No hay
/// login, cuenta ni configuración de cuenta dentro de la app — ese concepto
/// no existe aquí; solo se refleja el estado real de sync.
///
/// Reutiliza `SettingsModel.syncStatus` tal cual; no duplica ni toca la
/// lógica de CloudKit. El botón de regresar lo da el `NavigationStack`.
struct DataSettingsView: View {
    @Environment(\.lana) private var lana
    private let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md.rawValue) {
                LanaCard {
                    HStack(alignment: .top, spacing: Space.sm.rawValue) {
                        statusIcon
                        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                            Text(statusTitle)
                                .lanaFont(.headline)
                                .foregroundStyle(lana.textPrimary)
                            Text(statusDetail)
                                .lanaFont(.body)
                                .foregroundStyle(lana.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            // La fecha exacta bajo la relativa: "hace 2 horas"
                            // dice qué tan reciente, no cuándo. Para saber si
                            // un cambio de ayer alcanzó a respaldarse, hace
                            // falta el dato completo.
                            if case let .synced(lastSuccess) = model.syncStatus {
                                Text(lastSuccess.formatted(date: .abbreviated, time: .shortened))
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }

                // Dónde tocar, textual: no hay URL pública que abra la
                // configuración de iCloud, y mandar al usuario a la página de
                // Lana en Ajustes —lo único que `openSettingsURLString`
                // permite— sería un callejón sin salida cuando el problema es
                // la cuenta. El camino escrito sí lo lleva.
                if needsICloudWayfinding {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                            Text("Dónde revisarlo")
                                .lanaFont(.headline)
                                .foregroundStyle(lana.textPrimary)
                            Text("Ajustes › tu nombre › iCloud › Apps que usan iCloud")
                                .lanaFont(.body)
                                .foregroundStyle(lana.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text("""
                Los datos de esta app se almacenan en tu iCloud, usando la cuenta que ya \
                tienes configurada en este dispositivo.
                """)
                .lanaFont(.caption)
                .foregroundStyle(lana.textSecondary)
            }
            .padding(Space.md.rawValue)
            .floatingMicClearance()
        }
        .background(lana.surface)
        .navigationTitle("iCloud")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch model.syncStatus {
        case .disabled:
            Image(systemName: "icloud.slash").foregroundStyle(lana.textSecondary)
        case .syncing:
            ProgressView().controlSize(.small)
        case .synced:
            Image(systemName: "checkmark.icloud").foregroundStyle(lana.accent)
        case .failed:
            Image(systemName: "exclamationmark.icloud").foregroundStyle(lana.warning)
        }
    }

    /// Solo cuando hay algo que el usuario pueda ir a revisar. Sincronizando o
    /// ya sincronizado, el camino a Ajustes sobra.
    private var needsICloudWayfinding: Bool {
        switch model.syncStatus {
        case .disabled, .failed: true
        case .syncing, .synced: false
        }
    }

    private var statusTitle: String {
        switch model.syncStatus {
        case .disabled: "Sin iCloud activo"
        case .syncing: "Sincronizando…"
        case .synced: "Sincronizado con iCloud"
        case .failed: "No se pudo respaldar la última vez"
        }
    }

    private var statusDetail: String {
        switch model.syncStatus {
        case .disabled:
            "Tus datos solo viven en este dispositivo."
        case .syncing:
            "Estamos poniendo tus datos al día en iCloud."
        case let .synced(lastSuccess):
            "Última vez \(lastSuccess.formatted(.relative(presentation: .named)))."
        case .failed:
            """
            Tus datos siguen aquí, en tu dispositivo. Revisa tu conexión o el espacio \
            disponible en iCloud.
            """
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            DataSettingsView(model: SettingsModel(
                vocabularyStore: InMemoryCorrectionVocabularyStore(),
                syncStatusReporting: InMemorySyncStatusReporting(.synced(lastSuccess: .now)),
                userDefaults: UserDefaults(suiteName: "preview") ?? .standard))
        }
        .lanaTheme(theme)
    }
}

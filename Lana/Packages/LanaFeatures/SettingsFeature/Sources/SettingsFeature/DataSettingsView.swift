import LanaCore
import LanaDesign
import SwiftUI

/// "iCloud": el estado real de sincronización (ADR-0020).
///
/// No hay login ni cuenta dentro de la app — ese concepto no existe aquí: se
/// usa la cuenta de iCloud que ya tiene el dispositivo, y esta pantalla solo
/// refleja cómo va. Se empuja desde Ajustes, así que no lleva barra.
struct DataSettingsView: View {
    @Environment(\.lana) private var lana
    private let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statusCard
                    .padding(.bottom, Space.p12.rawValue)

                // Dónde tocar, en texto: no hay URL pública que abra la
                // configuración de iCloud, y mandar a la página de Lana en
                // Ajustes sería un callejón sin salida cuando el problema es la
                // cuenta. El camino escrito sí lleva.
                if needsICloudWayfinding {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                            Text("Dónde revisarlo")
                                .lanaFont(.bodyEmphasis)
                                .foregroundStyle(lana.ink)
                            Text("Ajustes › tu nombre › iCloud › Apps que usan iCloud")
                                .lanaFont(.explanation)
                                .foregroundStyle(lana.ink70)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, Space.p12.rawValue)
                }

                Text("""
                Tus movimientos viven en tu iCloud, con la cuenta que ya tienes configurada en este \
                iPhone.
                """)
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .tabBarClearance(.noTabBar)
        }
        .background(lana.bg)
        .navigationTitle("iCloud")
        .lanaInlineNavigationTitle()
        .hidesLanaTabBar()
    }

    private var statusCard: some View {
        LanaCard(radius: .cardLarge) {
            HStack(alignment: .top, spacing: Space.p12.rawValue) {
                statusIcon
                VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                    Text(statusTitle)
                        .lanaFont(.pushTitle)
                        .foregroundStyle(lana.ink)
                    Text(statusDetail)
                        .lanaFont(.explanation)
                        .foregroundStyle(lana.ink70)
                        .fixedSize(horizontal: false, vertical: true)
                    // La fecha exacta bajo la relativa: "hace 2 horas" dice qué
                    // tan reciente, no cuándo. Para saber si un cambio de ayer
                    // alcanzó a respaldarse hace falta el dato completo.
                    if case let .synced(lastSuccess) = model.syncStatus {
                        Text(lastSuccess.formatted(date: .abbreviated, time: .shortened))
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.ink42)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch model.syncStatus {
        case .disabled:
            Image(systemName: "icloud.slash").foregroundStyle(lana.attention)
        case .syncing:
            ProgressView().controlSize(.small)
        case .synced:
            Image(systemName: "checkmark.icloud").foregroundStyle(lana.positive)
        case .failed:
            Image(systemName: "exclamationmark.icloud").foregroundStyle(lana.attention)
        }
    }

    /// Solo cuando hay algo que ir a revisar. Sincronizando o ya al día, el
    /// camino a Ajustes sobra.
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
        case .synced: "iCloud al día"
        case .failed: "No se pudo respaldar la última vez"
        }
    }

    private var statusDetail: String {
        switch model.syncStatus {
        case .disabled:
            "Todo vive en este iPhone."
        case .syncing:
            "Estamos poniendo tus movimientos al día."
        case let .synced(lastSuccess):
            "Última vez \(lastSuccess.formatted(.relative(presentation: .named)))."
        case .failed:
            "Tus movimientos siguen aquí. Revisa tu conexión o el espacio en iCloud."
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

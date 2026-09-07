import LanaCore
import LanaDesign
import SwiftUI

/// Pantalla de emparejamiento de tarjetas — el orden de prioridad de señales
/// (R3.1), qué hacer cuando el nombre en Wallet difiere del alias (R3.2), qué
/// revisar si nada empareja (R3.3) y un enlace a Ajustes → Tarjetas (R3.4).
/// Sin lógica: refleja el contenido y llama el handler inyectado.
struct MatchingStepView: View {
    @Environment(\.lana) private var lana

    /// La explicación de emparejamiento y su orden de prioridad (R3).
    let matching: MatchingExplanation
    /// Abre Ajustes → Tarjetas para editar los datos de emparejamiento (R3.4).
    /// Inyectado desde `ContentView`, porque las features no se importan entre
    /// sí (Docs/ARCHITECTURE.md).
    let onOpenCardSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg.rawValue) {
            Text("Empareja tus tarjetas")
                .lanaFont(.title)
                .foregroundStyle(lana.textPrimary)

            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    Text("Lana empareja en este orden de prioridad:")
                        .lanaFont(.headline)
                        .foregroundStyle(lana.textPrimary)

                    ForEach(matching.prioritySignals) { signal in
                        HStack(alignment: .top, spacing: Space.sm.rawValue) {
                            // El número de prioridad (1-based sobre el id
                            // 0-based) se ve — no depende solo del orden.
                            ZStack {
                                Circle()
                                    .fill(lana.accentMuted)
                                    .frame(width: 28, height: 28)
                                Text("\(signal.id + 1)")
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.accent)
                            }
                            VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                                Text(signal.name)
                                    .lanaFont(.body)
                                    .foregroundStyle(lana.textPrimary)
                                Text(signal.explanation)
                                    .lanaFont(.caption)
                                    .foregroundStyle(lana.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            guidanceCard(systemImage: "pencil.and.list.clipboard", message: matching.mismatchGuidance)
            guidanceCard(systemImage: "questionmark.circle", message: matching.noMatchGuidance)

            Button(action: onOpenCardSettings) {
                Label("Abrir Ajustes → Tarjetas", systemImage: "creditcard")
            }
            .lanaFont(.body)
            .foregroundStyle(lana.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guidanceCard(systemImage: String, message: String) -> some View {
        LanaCard {
            HStack(alignment: .top, spacing: Space.sm.rawValue) {
                Image(systemName: systemImage)
                    .foregroundStyle(lana.accent)
                    .frame(width: 28)
                Text(message)
                    .lanaFont(.body)
                    .foregroundStyle(lana.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                MatchingStepView(
                    matching: GuiaApplePayContent.standard.matching,
                    onOpenCardSettings: {})
                    .padding(Space.md.rawValue)
                    .background(LanaColors(theme: theme, colorScheme: .light).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

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

            // Lo que el usuario tiene que hacer, separado de lo que solo
            // necesita entender: antes las cuatro tarjetas se veían iguales y
            // no se distinguía la acción de las dudas.
            section(header: "Qué tienes que hacer", systemImage: "checklist") {
                findNameCard

                Text("Luego regístralo en tu tarjeta dentro de Lana:")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.textSecondary)
                    .padding(.leading, Space.xs.rawValue)

                Button(action: onOpenCardSettings) {
                    Label("Ir a Tarjetas", systemImage: "creditcard")
                }
                .lanaFont(.body)
                .foregroundStyle(lana.accent)
                .padding(.leading, Space.xs.rawValue)
            }

            // Referencia: cómo decide Lana. Útil para entender, no algo que
            // el usuario tenga que ejecutar.
            section(header: "Cómo empareja Lana", systemImage: "info.circle") {
                prioritySignalsCard
            }

            // Solución de problemas: los casos de "si algo sale distinto".
            section(header: "Si algo no empareja", systemImage: "questionmark.circle") {
                guidanceCard(systemImage: "pencil.and.list.clipboard", message: matching.mismatchGuidance)
                guidanceCard(systemImage: "magnifyingglass", message: matching.noMatchGuidance)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Agrupa contenido bajo un encabezado que comunica el ROL del bloque
    /// (acción / referencia / dudas), para que las tarjetas dejen de verse
    /// como una lista plana e indistinta.
    private func section(
        header: String,
        systemImage: String,
        @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            Label(header, systemImage: systemImage)
                .lanaFont(.caption)
                .foregroundStyle(lana.textSecondary)
                .textCase(.uppercase)
            content()
        }
    }

    /// El orden de prioridad de señales (R3.1) — informativo.
    private var prioritySignalsCard: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
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
    }

    /// El paso que a la gente le cuesta: dónde ver el nombre que Wallet le da
    /// a la tarjeta. Va en pasos numerados —no un párrafo— porque el nombre
    /// no está a la vista: vive tras «Detalles de la tarjeta».
    private var findNameCard: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.md.rawValue) {
                Text("Encuentra el nombre de tu tarjeta en Wallet")
                    .lanaFont(.headline)
                    .foregroundStyle(lana.textPrimary)

                ForEach(matching.findNameSteps) { step in
                    HStack(alignment: .top, spacing: Space.sm.rawValue) {
                        // El número del paso se ve — no depende solo del orden.
                        ZStack {
                            Circle()
                                .fill(lana.accentMuted)
                                .frame(width: 28, height: 28)
                            Text("\(step.id)")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.accent)
                        }
                        VStack(alignment: .leading, spacing: Space.xs.rawValue) {
                            Text(step.title)
                                .lanaFont(.body)
                                .foregroundStyle(lana.textPrimary)
                            Text(step.detail)
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

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
        VStack(alignment: .leading, spacing: Space.p26.rawValue) {
            // Un encabezado dentro del paso, no un segundo título de guía.
            Text("Empareja tus tarjetas")
                .lanaFont(.screenTitle)
                .foregroundStyle(lana.ink)

            // Lo que el usuario tiene que hacer, separado de lo que solo
            // necesita entender: antes las cuatro tarjetas se veían iguales y
            // no se distinguía la acción de las dudas.
            section(header: "Qué tienes que hacer", systemImage: "checklist") {
                findNameCard

                Text("Luego regístralo en tu tarjeta dentro de Lana:")
                    .lanaFont(.explanation)
                    .foregroundStyle(lana.ink60)
                    .padding(.top, Space.xs.rawValue)

                Button(action: onOpenCardSettings) {
                    Label("Ir a Tarjetas", systemImage: "creditcard")
                }
                .lanaFont(.action)
                .foregroundStyle(lana.accent)
                .buttonStyle(.plain)
                .frame(minHeight: LanaMetrics.minTouchTarget)
            }

            // Referencia: cómo decide Lana. Útil para entender, no algo que
            // el usuario tenga que ejecutar.
            section(header: "Cómo empareja Lana", systemImage: "info.circle") {
                prioritySignalsCard
            }

            // Solución de problemas: los casos de "si algo sale distinto".
            section(header: "Si algo no empareja", systemImage: "questionmark.circle") {
                VStack(alignment: .leading, spacing: 0) {
                    guidanceRow(systemImage: "pencil.and.list.clipboard", message: matching.mismatchGuidance)
                    HairlineDivider(strong: true)
                    guidanceRow(systemImage: "magnifyingglass", message: matching.noMatchGuidance)
                }
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
        VStack(alignment: .leading, spacing: Space.p10.rawValue) {
            Label(header, systemImage: systemImage)
                .lanaFont(.sectionHeader)
                .foregroundStyle(lana.ink50)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// El orden de prioridad de señales (R3.1) — informativo.
    private var prioritySignalsCard: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.p14.rawValue) {
                ForEach(matching.prioritySignals) { signal in
                    // El número de prioridad (1-based sobre el id 0-based) se
                    // ve — no depende solo del orden.
                    numberedRow(number: signal.id + 1, title: signal.name, detail: signal.explanation)
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
            VStack(alignment: .leading, spacing: Space.p14.rawValue) {
                Text("Encuentra el nombre de tu tarjeta en Wallet")
                    .lanaFont(.pushTitle)
                    .foregroundStyle(lana.ink)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(matching.findNameSteps) { step in
                    numberedRow(number: step.id, title: step.title, detail: step.detail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func numberedRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.p12.rawValue) {
            GuideStepNumber(number: number)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.p2.rawValue) {
                Text(title)
                    .lanaFont(.rowTitle)
                    .foregroundStyle(lana.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func guidanceRow(systemImage: String, message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.p12.rawValue) {
            Image(systemName: systemImage)
                .lanaFont(.bodyEmphasis)
                .foregroundStyle(lana.ink50)
                .frame(width: LanaMetrics.badge)
                .accessibilityHidden(true)
            Text(message)
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.p12.rawValue)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                MatchingStepView(
                    matching: GuiaApplePayContent.standard.matching,
                    onOpenCardSettings: {})
                    .padding(LanaMetrics.onboardingMargin)
                    .background(LanaColors(theme: theme, colorScheme: .light).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

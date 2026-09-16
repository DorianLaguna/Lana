import LanaCore
import LanaDesign
import SwiftUI

/// Qué se ve cuando Apple Intelligence no está disponible (rediseño,
/// sección 14).
///
/// Cada caso de `ParsingAvailability` se trata distinto porque son problemas
/// distintos: uno es permanente, otro se arregla en Ajustes y otro solo
/// necesita tiempo. Ofrecer "reintentar" en un dispositivo que nunca va a
/// poder es prometer algo que no va a pasar.
///
/// Todos ofrecen **"Ver el año"**: las estadísticas puras no dependen del
/// modelo, así que perder el análisis no deja a nadie sin a dónde ir. El icono
/// va apagado, nunca en color: esto es una limitación, no una función premium.
struct InsightsUnavailableView: View {
    @Environment(\.lana) private var lana

    let availability: ParsingAvailability
    let onOpenSettings: (() -> Void)?
    let onRetry: () -> Void
    /// Abre El año, que funciona sin Apple Intelligence. `nil` donde no haya a
    /// dónde llevar.
    var onOpenYear: (() -> Void)?

    var body: some View {
        EmptyStateView(
            systemImage: "sparkles",
            title: title,
            message: message,
            actionTitle: action?.title,
            action: action?.perform,
            secondaryActionTitle: onOpenYear == nil ? nil : "Ver el año",
            secondaryAction: onOpenYear,
            showsProgress: availability == .modelNotReady)
    }

    private var title: String {
        switch availability {
        case .deviceNotEligible: "Este iPhone no puede hacer el análisis"
        case .notEnabled: "Apple Intelligence está desactivado"
        case .modelNotReady: "Lana se está preparando"
        case .available, .unknown: "No pudimos comprobar el análisis"
        }
    }

    private var message: String {
        switch availability {
        case .deviceNotEligible:
            "El resumen escrito necesita Apple Intelligence. El año, con sus cifras, está completo."
        case .notEnabled:
            "Actívalo para que Lana te explique tu mes. Lo procesa todo en tu iPhone."
        case .modelNotReady:
            "El modelo se está descargando. Puede tardar unos minutos."
        case .available, .unknown:
            "Vuelve a intentarlo en un momento."
        }
    }

    private var action: (title: String, perform: () -> Void)? {
        switch availability {
        case .deviceNotEligible:
            // Permanente: no se ofrece reintentar.
            nil
        case .notEnabled:
            onOpenSettings.map { ("Abrir Ajustes", $0) }
        case .unknown:
            ("Reintentar", onRetry)
        case .modelNotReady, .available:
            // Se revisa sola mientras se descarga.
            nil
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(
                [ParsingAvailability.deviceNotEligible, .notEnabled, .modelNotReady, .unknown],
                id: \.self) { availability in
                    InsightsUnavailableView(
                        availability: availability,
                        onOpenSettings: {},
                        onRetry: {},
                        onOpenYear: {})
                }
        }
        .padding(LanaMetrics.screenMargin)
    }
}

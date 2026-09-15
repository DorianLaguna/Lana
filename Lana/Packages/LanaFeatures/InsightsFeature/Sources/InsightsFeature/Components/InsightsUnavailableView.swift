import LanaCore
import LanaDesign
import SwiftUI

/// Qué se ve cuando Apple Intelligence no está disponible.
///
/// Cada caso de `ParsingAvailability` se trata distinto porque son problemas
/// distintos: uno es permanente, otro se arregla en Ajustes y otro solo
/// necesita tiempo. Ofrecer "reintentar" en un dispositivo que nunca va a
/// poder es prometer algo que no va a pasar.
///
/// `EntryFeature` resuelve lo mismo para la captura, pero las features no se
/// importan entre sí (Docs/ARCHITECTURE.md), así que aquí va su propia copia
/// con copy propia: el análisis es una comodidad, no la captura — perderlo no
/// deja la app inservible, y el texto lo dice.
struct InsightsUnavailableView: View {
    @Environment(\.lana) private var lana

    let availability: ParsingAvailability
    let onOpenSettings: (() -> Void)?
    let onRetry: () -> Void

    var body: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.md.rawValue) {
                Text(title)
                    .lanaFont(.headline)
                    .foregroundStyle(lana.ink)
                Text(message)
                    .lanaFont(.body)
                    .foregroundStyle(lana.ink50)
                if let action {
                    Button(action.title, action: action.perform)
                        .buttonStyle(.borderedProminent)
                        .tint(lana.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var title: String {
        switch availability {
        case .deviceNotEligible: "Este iPhone no puede hacer el análisis"
        case .notEnabled: "Apple Intelligence está apagado"
        case .modelNotReady: "El modelo se está preparando"
        case .available, .unknown: "El análisis no está disponible"
        }
    }

    private var message: String {
        switch availability {
        case .deviceNotEligible:
            """
            El resumen escrito necesita Apple Intelligence, que este modelo de \
            iPhone no soporta. Todo lo demás de Lana funciona igual: la vista \
            del año, con sus totales y gráficas, está completa.
            """
        case .notEnabled:
            """
            Se activa desde Ajustes del sistema. Mientras tanto, la vista del \
            año tiene las mismas cifras sin texto de por medio.
            """
        case .modelNotReady:
            """
            El sistema todavía está descargando el modelo. Puede tardar un \
            rato; vuelve a intentar más tarde.
            """
        case .available, .unknown:
            """
            No se pudo consultar el modelo del sistema. La vista del año sigue \
            disponible con todas las cifras.
            """
        }
    }

    private var action: (title: String, perform: () -> Void)? {
        switch availability {
        case .deviceNotEligible:
            // Permanente: no se ofrece reintentar.
            nil
        case .notEnabled:
            onOpenSettings.map { ("Abrir Ajustes", $0) }
        case .modelNotReady, .unknown:
            ("Volver a intentar", onRetry)
        case .available:
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
                    InsightsUnavailableView(availability: availability, onOpenSettings: {}, onRetry: {})
                }
        }
        .padding(Space.md.rawValue)
    }
}

import LanaCore
import LanaDesign
import SwiftUI

/// Los 4 casos de `ParsingAvailability`, cada uno con tratamiento distinto
/// (Docs/.claude/skills/foundation-models): `.deviceNotEligible` es
/// permanente y no ofrece reintentar; `.notEnabled` lleva a Settings;
/// `.modelNotReady` ofrece reintentar. `.available` nunca llega aquí — la
/// vista que la contiene cambia de pantalla antes.
public struct AvailabilityOnboardingView: View {
    @Environment(\.lana) private var lana

    private let availability: ParsingAvailability
    private let onOpenSettings: () -> Void
    private let onRetry: () async -> Void

    public init(
        availability: ParsingAvailability,
        onOpenSettings: @escaping () -> Void,
        onRetry: @escaping () async -> Void) {
        self.availability = availability
        self.onOpenSettings = onOpenSettings
        self.onRetry = onRetry
    }

    public var body: some View {
        switch availability {
        case .available:
            EmptyView()
        case .deviceNotEligible:
            EmptyStateView(
                systemImage: "iphone.slash",
                title: "Este dispositivo no soporta Apple Intelligence",
                message: """
                Lana necesita el modelo del sistema para entender lo que \
                escribes. En este equipo no está disponible.
                """)
        case .notEnabled:
            EmptyStateView(
                systemImage: "gear",
                title: "Apple Intelligence está apagado",
                message: "Actívalo en Ajustes para que Lana pueda entender lo que escribes.",
                actionTitle: "Abrir Ajustes",
                action: onOpenSettings)
        case .modelNotReady:
            EmptyStateView(
                systemImage: "arrow.down.circle",
                title: "El modelo se está preparando",
                message: "Esto pasa una sola vez. Intenta de nuevo en un momento.",
                actionTitle: "Reintentar",
                action: { Task { await onRetry() } })
        case .unknown:
            EmptyStateView(
                systemImage: "questionmark.circle",
                title: "No se pudo revisar la disponibilidad",
                actionTitle: "Reintentar",
                action: { Task { await onRetry() } })
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                LanaCard {
                    AvailabilityOnboardingView(
                        availability: .notEnabled,
                        onOpenSettings: {},
                        onRetry: {})
                }
                .lanaTheme(theme)
            }
        }
        .padding(Space.md.rawValue)
    }
}

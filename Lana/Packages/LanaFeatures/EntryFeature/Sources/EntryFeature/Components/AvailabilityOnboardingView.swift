import LanaCore
import LanaDesign
import SwiftUI

/// Los cuatro casos en que no se puede dictar porque Apple Intelligence no
/// está disponible (rediseño, sección 14). Todos ofrecen "Agregar a mano":
/// la app tiene que seguir siendo usable. El icono va apagado, nunca en color
/// — no es una función premium, es una limitación.
public struct AvailabilityOnboardingView: View {
    @Environment(\.lana) private var lana

    private let availability: ParsingAvailability
    private let onOpenSettings: () -> Void
    private let onRetry: () async -> Void
    private let onManualEntry: () -> Void

    /// Cada cuánto se vuelve a revisar mientras el modelo se descarga.
    private static var modelPollInterval: Duration {
        .seconds(5)
    }

    public init(
        availability: ParsingAvailability,
        onOpenSettings: @escaping () -> Void,
        onRetry: @escaping () async -> Void,
        onManualEntry: @escaping () -> Void) {
        self.availability = availability
        self.onOpenSettings = onOpenSettings
        self.onRetry = onRetry
        self.onManualEntry = onManualEntry
    }

    public var body: some View {
        switch availability {
        case .available:
            EmptyView()
        case .deviceNotEligible:
            EmptyStateView(
                systemImage: "sparkles",
                title: "Este iPhone no puede dictar a Lana",
                message: "Puedes registrar tus movimientos a mano; todo lo demás funciona igual.",
                actionTitle: "Agregar a mano",
                action: onManualEntry)
        case .notEnabled:
            EmptyStateView(
                systemImage: "sparkles",
                title: "Apple Intelligence está desactivado",
                message: "Actívalo para dictar tus gastos. Lana lo procesa todo en tu iPhone.",
                actionTitle: "Abrir Ajustes",
                action: onOpenSettings,
                secondaryActionTitle: "Agregar a mano",
                secondaryAction: onManualEntry)
        case .modelNotReady:
            EmptyStateView(
                systemImage: "sparkles",
                title: "Lana se está preparando",
                message: "El modelo de voz se está descargando. Puede tardar unos minutos.",
                secondaryActionTitle: "Agregar a mano",
                secondaryAction: onManualEntry,
                showsProgress: true)
                // Sin botón de reintentar: se revisa sola hasta que esté lista.
                .task {
                    try? await Task.sleep(for: Self.modelPollInterval)
                    guard !Task.isCancelled else { return }
                    await onRetry()
                }
        case .unknown:
            EmptyStateView(
                systemImage: "sparkles",
                title: "No pudimos comprobar el dictado",
                message: "Vuelve a intentarlo en un momento.",
                actionTitle: "Reintentar",
                action: { Task { await onRetry() } },
                secondaryActionTitle: "Agregar a mano",
                secondaryAction: onManualEntry)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.md.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                AvailabilityOnboardingView(
                    availability: .notEnabled,
                    onOpenSettings: {},
                    onRetry: {},
                    onManualEntry: {})
                    .background(LanaColors(theme: theme, colorScheme: .dark).surface)
                    .lanaTheme(theme)
            }
        }
    }
}

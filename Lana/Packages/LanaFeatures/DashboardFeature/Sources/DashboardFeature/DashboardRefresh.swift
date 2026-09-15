import Foundation

/// El refresco de Hoy y Mes. Vive aquí, y no dentro de una de las dos
/// pantallas, porque las dos comparten modelos y los dos lo necesitan (al
/// aparecer, al jalar para refrescar y al volver a primer plano).
@MainActor
public enum DashboardRefresh {
    /// Primero los recurrentes vencidos (puede crear movimientos nuevos),
    /// luego el mes — si no, el mes se carga sin lo que se acaba de registrar
    /// automáticamente.
    public static func run(
        dashboard: DashboardModel,
        recurringItems: RecurringItemsModel,
        upcomingCardPayments: UpcomingCardPaymentsModel) async {
        await recurringItems.onAppear()
        await recurringItems.registerDueItems()
        await dashboard.onAppear()
        await upcomingCardPayments.onAppear()
    }
}

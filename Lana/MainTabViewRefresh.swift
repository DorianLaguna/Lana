import CardsFeature
import DashboardFeature
import LanaCore
import SharedFeature
import SwiftUI
import UIKit

/// El refresco central de la app y el salto a Ajustes del sistema.
///
/// Vive aquí y no en `MainTabView.swift` solo para que ese archivo no rebase
/// el largo máximo. Es la misma vista y la misma responsabilidad: un solo
/// lugar decide qué se refresca cuando cambia un gasto (ADR-0032).
extension MainTabView {
    /// Hoy y Mes: recurrentes vencidos, el mes y los pagos de la quincena.
    func refreshDashboard() async {
        await DashboardRefresh.run(
            dashboard: dashboardModel,
            recurringItems: recurringItemsModel,
            upcomingCardPayments: upcomingCardPaymentsModel)
    }

    /// Todo lo que puede quedar viejo cuando se crea, edita o borra un gasto
    /// desde cualquier punto de la app. Agregar una pantalla nueva que
    /// dependa de los gastos se hace aquí, no en cada `onDone` (ADR-0032).
    func refreshAfterExpenseChange() async {
        await dashboardModel.onAppear()
        // Borrar el movimiento de un recurrente lo deja pendiente otra vez
        // (ADR-0042).
        await recurringItemsModel.onAppear()
        await upcomingCardPaymentsModel.onAppear()
        // Solo si ya se entró al año: si no, esto pagaría una lectura de
        // veinticuatro meses por cada gasto capturado.
        await yearModel.refreshIfLoaded()
        await cardsModel.onAppear()
        // El detalle de tarjeta empujado es una instancia aparte con su propia
        // copia de gastos.
        await cardsModel.refreshCurrentCardDetail()
        // El gasto puede ser compartido.
        await sharedListModel.refreshCurrentDetail()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    MainTabView(dependencies: .preview(), environment: InMemoryApplePayEnvironment())
}

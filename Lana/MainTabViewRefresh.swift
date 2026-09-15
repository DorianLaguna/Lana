import CardsFeature
import DashboardFeature
import LanaCore
import SharedFeature
import SwiftUI
import UIKit

/// El refresco central de la app y el salto a Ajustes del sistema.
///
/// Viven aquí y no en `MainTabView.swift` solo para que ese archivo no rebase
/// el largo máximo (`swiftlint`, `file_length`). Es la misma vista y la misma
/// responsabilidad: un solo lugar decide qué se refresca cuando cambia un
/// gasto (ADR-0032).
extension MainTabView {
    /// Todo lo que puede quedar viejo cuando se crea, edita o borra un
    /// gasto desde cualquier punto de la app. Un solo lugar a propósito:
    /// cada hoja tenía su propia lista de refrescos y capturar un gasto
    /// nuevo refrescaba Dashboard y Compartido pero no Tarjetas, así que
    /// estando dentro de una tarjeta el cargo recién capturado no aparecía
    /// hasta salir y volver a entrar (ADR-0032). Agregar una pantalla nueva
    /// que dependa de los gastos se hace aquí, no en cada `onDone`.
    func refreshAfterExpenseChange() async {
        await dashboardModel.onAppear()
        // Solo si el usuario ya entró alguna vez al año: si no, esto pagaría
        // una lectura de veinticuatro meses por cada gasto capturado, para una
        // pantalla que nadie está viendo.
        await yearModel.refreshIfLoaded()
        await refreshSurfacesOutsideDashboard()
    }

    /// Lo mismo, sin el Dashboard — para cuando el aviso viene de adentro
    /// del propio Dashboard, que ya se refrescó a sí mismo antes de avisar
    /// (`DashboardView`, hoja de editar). Refrescarlo otra vez sería una
    /// lectura de más y un parpadeo de su spinner.
    func refreshSurfacesOutsideDashboard() async {
        await cardsModel.onAppear()
        // `cardsModel.onAppear()` solo refresca la lista de tarjetas y su
        // deuda — el detalle empujado en el stack (si el usuario está
        // drilled-down en una tarjeta) es una instancia aparte con su
        // propia copia de gastos.
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

import SwiftUI

public extension View {
    /// Esconde la barra de navegación en una pantalla raíz que dibuja su propio
    /// encabezado (Hoy, Mes). Solo existe en iOS; los paquetes también
    /// compilan en macOS para `swift test`.
    @ViewBuilder
    func lanaHidesNavigationBar() -> some View {
        #if os(iOS)
            toolbar(.hidden, for: .navigationBar)
        #else
            self
        #endif
    }

    /// El título de un push, chico y centrado.
    @ViewBuilder
    func lanaInlineNavigationTitle() -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(.inline)
        #else
            self
        #endif
    }
}

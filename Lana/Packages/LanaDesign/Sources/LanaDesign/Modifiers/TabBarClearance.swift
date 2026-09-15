import SwiftUI

/// Cuánto aire deja una pantalla al final de su scroll.
public enum ScrollTail: Sendable {
    /// 120 pt: cualquier pestaña.
    case standard
    /// 132 pt: Hoy.
    case today
    /// 60 pt: pantallas sin barra de pestañas (Ajustes).
    case noTabBar

    var height: CGFloat {
        switch self {
        case .standard: LanaMetrics.scrollTail
        case .today: LanaMetrics.scrollTailToday
        case .noTabBar: LanaMetrics.scrollTailNoTabBar
        }
    }
}

public extension View {
    /// El colchón inferior que libra al contenido de la barra de pestañas
    /// flotante. Es el arreglo directo al bug del micrófono que tapaba filas
    /// y montos: ninguna pantalla con barra puede terminar su scroll sin él.
    func tabBarClearance(_ tail: ScrollTail = .standard) -> some View {
        padding(.bottom, tail.height)
    }
}

import Observation
import SwiftUI

/// El estado del chrome que la app dibuja alrededor de las pantallas — hoy,
/// solo si la barra de pestañas se ve.
///
/// Ajustes se empuja desde Hoy pero no lleva barra (rediseño, sección 12).
/// Las features no conocen la barra (vive en la app), así que una pantalla la
/// esconde declarándolo con `hidesLanaTabBar()`, y la app lee este objeto.
/// Cuenta peticiones en vez de guardar un `Bool`: al empujar Aprendizaje
/// desde Ajustes, la pantalla nueva aparece antes de que la anterior
/// desaparezca, y un `Bool` dejaría la barra visible un instante de más.
@MainActor
@Observable
public final class LanaChrome {
    private var hideRequests = 0

    /// `true` mientras alguna pantalla visible pida esconder la barra.
    public var isTabBarHidden: Bool {
        hideRequests > 0
    }

    /// Arranca con la barra visible. La app crea uno y lo pone en el entorno.
    public init() {}

    func requestTabBarHidden() {
        hideRequests += 1
    }

    func releaseTabBarHidden() {
        hideRequests = max(hideRequests - 1, 0)
    }
}

public extension EnvironmentValues {
    /// El chrome de la app, si la pantalla vive dentro de la barra de pestañas.
    @Entry var lanaChrome: LanaChrome?
}

public extension View {
    /// Esconde la barra de pestañas mientras esta pantalla esté visible.
    func hidesLanaTabBar() -> some View {
        modifier(HidesLanaTabBar())
    }
}

private struct HidesLanaTabBar: ViewModifier {
    @Environment(\.lanaChrome) private var chrome

    func body(content: Content) -> some View {
        content
            .onAppear { chrome?.requestTabBarHidden() }
            .onDisappear { chrome?.releaseTabBarHidden() }
    }
}

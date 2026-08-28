import SwiftUI

public extension EnvironmentValues {
    /// El tema elegido por el usuario. Por defecto `.cobalto`.
    @Entry var lanaTheme: LanaTheme = .default

    /// Los colores resueltos para el tema y la apariencia (claro/oscuro)
    /// vigentes. El punto de entrada normal a `LanaColors` desde una vista:
    /// `@Environment(\.lana) private var lana`.
    var lana: LanaColors {
        LanaColors(theme: lanaTheme, colorScheme: colorScheme)
    }
}

public extension View {
    /// Fija el tema para esta vista y sus hijas.
    func lanaTheme(_ theme: LanaTheme) -> some View {
        environment(\.lanaTheme, theme)
    }
}

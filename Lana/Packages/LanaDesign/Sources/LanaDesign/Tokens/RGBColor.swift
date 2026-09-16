import Foundation

/// Un color en RGB (0...1 por canal), independiente de SwiftUI. Existe para
/// poder calcular contraste WCAG en `swift test` sin un contexto de
/// renderizado — `LanaColors` lo convierte a `Color` para las vistas.
struct RGBColor: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Construye desde un hex `#RRGGBB`. `fatalError` en un hex mal formado
    /// es una invariante de programación real: son constantes fijas del
    /// paquete, nunca datos de usuario.
    init(hex: String) {
        var value = hex
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else {
            fatalError("Hex de color inválido: \(hex)")
        }
        red = Double((rgb >> 16) & 0xFF) / 255
        green = Double((rgb >> 8) & 0xFF) / 255
        blue = Double(rgb & 0xFF) / 255
    }

    /// Luminancia relativa WCAG 2.x.
    var relativeLuminance: Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// Razón de contraste WCAG 2.x entre `self` y `other`: 1 (idéntico) a 21
    /// (blanco puro sobre negro puro). El mínimo para texto normal es 4.5.
    func contrastRatio(with other: RGBColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

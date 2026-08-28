import SwiftUI

public extension Color {
    /// Construye desde un hex `#RRGGBB`, o `nil` si está mal formado —
    /// a diferencia de `RGBColor.init(hex:)` (que revienta a propósito,
    /// pero solo es seguro para constantes fijas del paquete), esto sí
    /// puede recibir dato guardado por el usuario (el color de una
    /// tarjeta) y nunca debe tronar la app por una fila vieja o corrupta.
    init?(hex: String) {
        var value = hex
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else {
            return nil
        }
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1)
    }
}

/// Una paleta curada para que el usuario distinga tarjetas entre sí —
/// separada de los temas (ADR-0006, que sí son de la app entera): esto es
/// una etiqueta de color por objeto, elegida libremente.
public enum LanaCardColors {
    /// Los hex disponibles para elegir el color de una tarjeta.
    public static let palette: [String] = [
        "#1B4FD8", // azul
        "#2B2B33", // negro
        "#6C4FB3", // morado
        "#2F7A4F", // verde
        "#C2185B", // rosa
        "#E8590C" // naranja
    ]
}

import Foundation

/// Radios de esquina con nombre (ADR-0044). Píldoras, botones, chips y
/// avatares no están aquí: usan `Capsule()`/`Circle()`.
public enum Radius: CGFloat, Sendable, CaseIterable {
    /// Segmentos del progreso de la guía, barra vertical de una tarjeta.
    case hairline = 2
    /// Barras de la vista anual.
    case bar = 3
    /// Rectángulo de color de una tarjeta bancaria, glifo de detener.
    case swatch = 5
    /// Bloque de saldo dentro de una lista compartida.
    case block = 12
    /// Bloque interno sobre tarjeta, filas destacadas.
    case inner = 14
    /// Tarjeta o agrupación.
    case card = 16
    /// Tarjeta grande.
    case cardLarge = 18
    /// Hoja del Análisis.
    case sheetSmall = 26
    /// Hoja modal.
    case sheet = 28
    /// Barra de pestañas.
    case tabBar = 30
}

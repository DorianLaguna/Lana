import Foundation

/// Por dónde entró un movimiento (ADR-0049). Se fija al registrarlo y ninguna
/// corrección lo cambia: confirmar un pago de Apple Pay no lo vuelve dictado.
///
/// Lo que se registró antes de que existiera no lo trae (`nil`): no se infiere,
/// porque adivinar "de Apple Pay" por el concepto o la tarjeta confundiría al
/// usuario justo en lo que este dato promete aclarar.
public enum CaptureSource: String, Sendable, Hashable, Codable, CaseIterable {
    /// Dictado o texto, pasando por el parser.
    case dictation
    /// La automatización de Atajos con Wallet (ADR-0009).
    case applePay
    /// El formulario: registro manual (ADR-0035) o un gasto de lista compartida.
    case manual
    /// Un recurrente, a mano o por el registro automático (ADR-0042).
    case recurring
}

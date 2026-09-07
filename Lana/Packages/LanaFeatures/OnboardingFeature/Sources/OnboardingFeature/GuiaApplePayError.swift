import Foundation

/// Los errores de la `Guia_ApplePay` (ADR-0009). La guía no persiste datos, así
/// que sus "errores" son estados de UI recuperables, no fallos de dominio: cada
/// caso trae un mensaje en español con acción clara (Docs/CONVENTIONS.md).
/// Ningún caso usa `fatalError` ni `NSError` genérico.
///
/// Los indicadores de estado que acompañan estos errores en la UI combinan
/// siempre ícono + texto, nunca solo color (Docs/CONVENTIONS.md).
public enum GuiaApplePayError: LocalizedError {
    /// No se pudo cargar el contenido de la guía (R1.5) o el resumen de cierre
    /// (R6.2).
    case contentUnavailable
    /// El dispositivo no puede crear la automatización porque falta la app
    /// Atajos o el disparador de Wallet (R2.6).
    case automationUnsupported
    /// El avance del onboarding falló tras confirmar la finalización (R6.4).
    case onboardingAdvanceFailed

    public var errorDescription: String? {
        switch self {
        case .contentUnavailable:
            "No se pudo cargar la guía. Intenta de nuevo."
        case .automationUnsupported:
            "Este dispositivo no puede crear la automatización: falta la app Atajos o el disparador de Wallet."
        case .onboardingAdvanceFailed:
            "No se pudo continuar. Intenta de nuevo."
        }
    }
}

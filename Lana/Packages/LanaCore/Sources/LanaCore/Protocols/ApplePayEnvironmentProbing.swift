import Foundation

/// Responde si el entorno actual puede siquiera armar la automatización de
/// Atajos que alimenta la captura automática de Apple Pay (ADR-0009). La
/// `Guia_ApplePay` lo usa para avisar cuando el disparador de Wallet o la app
/// Atajos no están disponibles (R2.6) y para resaltar la limitación del
/// simulador (R5.2).
///
/// Vive en `LanaCore` para mantener el núcleo en `Foundation` puro: la
/// implementación real la provee el target de la app (consulta capacidades del
/// dispositivo/simulador), y la de prueba en memoria vive junto al protocolo,
/// igual que el resto de capacidades del sistema.
///
/// Nombre fijado por Docs/CONVENTIONS.md — sufijo `-ing`, como
/// `ExpenseParsing`/`SpeechTranscribing`.
public protocol ApplePayEnvironmentProbing: Sendable {
    /// `false` cuando el disparador de Wallet o la app Atajos no están
    /// disponibles en el dispositivo — la automatización no puede crearse
    /// (R2.6).
    var isShortcutsAutomationAvailable: Bool { get }
    /// `true` cuando corre en el simulador de iOS — la captura no puede
    /// probarse ahí porque no permite agregar tarjetas a la Wallet simulada
    /// (R5.2).
    var isRunningInSimulator: Bool { get }
}

/// Implementación en memoria para tests y `#Preview` — valores fijos, sin
/// consultar nada del sistema.
public struct InMemoryApplePayEnvironment: ApplePayEnvironmentProbing {
    public let isShortcutsAutomationAvailable: Bool
    public let isRunningInSimulator: Bool

    public init(
        isShortcutsAutomationAvailable: Bool = true,
        isRunningInSimulator: Bool = false) {
        self.isShortcutsAutomationAvailable = isShortcutsAutomationAvailable
        self.isRunningInSimulator = isRunningInSimulator
    }
}

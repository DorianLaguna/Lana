import Foundation
import LanaCore

/// `ApplePayEnvironmentProbing` real, en el target de la app porque lee el
/// entorno de ejecución (dispositivo vs. simulador) — algo que `LanaCore` no
/// puede tocar sin salirse de `Foundation` puro (ADR-0002, ARCHITECTURE.md).
/// La `Guia_ApplePay` lo consulta para avisar que la automatización de Atajos
/// no puede armarse (R2.6) y para resaltar que la captura no es probable en el
/// simulador (R5.2).
///
/// No hay API pública para preguntarle a iOS "¿existe el disparador Wallet de
/// Atajos aquí?": el trigger de automatización de Wallet (introducido en iOS
/// 17, renombrado "Wallet" en iOS 26) solo vive dentro de la app Atajos y no
/// se expone al proceso de la app. Por eso `isShortcutsAutomationAvailable` es
/// una determinación best-effort, no una comprobación exacta — su validación
/// real es manual, en un dispositivo físico, fuera de los tests automatizados
/// (ver tasks.md: "verificación manual en dispositivo").
struct ApplePayEnvironmentProbe: ApplePayEnvironmentProbing {
    /// `true` solo en compilación para el simulador de iOS. Es la única señal
    /// confiable y sin ambigüedad del entorno: se resuelve en tiempo de
    /// compilación, no depende de ninguna heurística (R5.2).
    var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    /// Best-effort: en el simulador la automatización de Wallet no puede
    /// armarse ni probarse (no se pueden agregar tarjetas a la Wallet
    /// simulada — R5.2), así que devolvemos `false` ahí. En un dispositivo
    /// físico con un iOS soportado asumimos que el disparador y la app Atajos
    /// están disponibles y devolvemos `true`; no existe forma pública de
    /// confirmarlo con precisión, y la guía deja claro que la comprobación
    /// definitiva la hace el usuario al crear la automatización (R2.6).
    var isShortcutsAutomationAvailable: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            true
        #endif
    }
}

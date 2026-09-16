import Foundation
import LanaCore

/// El nivel del micrófono que mueve la onda mientras se dicta (rediseño,
/// sección 07). Aparte de `EntryModel.swift` por tamaño, igual que
/// `EntryModelLivePreview.swift`.
extension EntryModel {
    /// Empieza a leer el volumen del micrófono. Cancela el anterior: "Borrar
    /// y seguir escuchando" abre una sesión nueva y con ella un stream nuevo.
    func startLevelMonitoring() {
        levelTask?.cancel()
        let levels = speech.audioLevels()
        levelTask = Task { [weak self] in
            for await level in levels {
                guard !Task.isCancelled else { return }
                self?.audioLevel = level
            }
        }
    }

    /// Deja de leer y aplana la onda: sin sesión de escucha no hay nivel que
    /// mostrar.
    func stopLevelMonitoring() {
        levelTask?.cancel()
        levelTask = nil
        audioLevel = 0
    }
}

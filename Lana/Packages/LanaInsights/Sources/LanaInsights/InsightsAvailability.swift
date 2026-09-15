import Foundation
import FoundationModels
import LanaCore

/// El único lugar de este paquete que toca `SystemLanguageModel`. Traduce su
/// disponibilidad al enum de `LanaCore`, para que las features nunca tengan
/// que importar `FoundationModels`.
///
/// Calca `LanaParsing.ParserAvailability`: son dos paquetes distintos y
/// ninguno puede importar al otro, así que la traducción se repite. Si Apple
/// agrega un caso de `UnavailableReason`, hay que tocar los dos.
enum InsightsAvailability {
    static var current: ParsingAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            .available
        case let .unavailable(reason):
            switch reason {
            case .deviceNotEligible: .deviceNotEligible
            case .appleIntelligenceNotEnabled: .notEnabled
            case .modelNotReady: .modelNotReady
            @unknown default: .unknown
            }
        @unknown default:
            .unknown
        }
    }
}

/// Los errores que este paquete puede mostrarle al usuario, en español y con
/// una acción clara (Docs/CONVENTIONS.md → Errores).
public enum InsightsError: LocalizedError, Sendable {
    case modelUnavailable(ParsingAvailability)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            "El modelo del sistema no está disponible ahora mismo."
        }
    }
}

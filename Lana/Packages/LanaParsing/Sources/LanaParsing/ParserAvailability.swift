import FoundationModels
import LanaCore

/// Traduce la disponibilidad de `FoundationModels` al tipo protocol-agnóstico
/// `LanaCore.ParsingAvailability` — las features consumen ese, nunca esto.
enum ParserAvailability {
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

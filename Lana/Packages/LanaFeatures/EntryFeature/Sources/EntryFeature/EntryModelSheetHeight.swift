import Foundation

/// Cuánto alto pide la hoja de captura. Aparte de `EntryModel.swift` por
/// tamaño, igual que `EntryModelLivePreview.swift`.
public extension EntryModel {
    /// Vive en el modelo y no en la vista por la misma razón que `stage`: es
    /// una consecuencia de en qué punto va la captura, no una decisión de
    /// presentación.
    ///
    /// Antes era binario (compacta o pantalla completa) y el salto se sentía
    /// brusco: a la palabra 50 la hoja pegaba un brinco a ocupar toda la
    /// pantalla. Ahora crece por escalones, acompañando lo que se va diciendo:
    ///
    /// - **Revisando**: los campos del borrador no caben; toda la pantalla.
    /// - **Escuchando**: sube de compacta a media cuando el transcript pasa de
    ///   dos renglones, y de media a completa solo cuando ya es una frase
    ///   larga. El umbral es por número de caracteres, no por renglones
    ///   medidos.
    var captureHeight: CaptureHeight {
        switch stage {
        case .reviewing, .saving:
            .full
        case .listening:
            switch inputText.count {
            case ...Self.transcriptLengthForMediumSheet:
                // El preview en vivo no cabe en la hoja compacta.
                liveDrafts.isEmpty ? .compact : .medium
            case ...Self.transcriptLengthForFullSheet:
                .medium
            default:
                .full
            }
        case .checkingAvailability, .unavailable, .composing, .parsing, .saved:
            .compact
        }
    }

    internal static var transcriptLengthForMediumSheet: Int {
        50
    }

    internal static var transcriptLengthForFullSheet: Int {
        140
    }
}

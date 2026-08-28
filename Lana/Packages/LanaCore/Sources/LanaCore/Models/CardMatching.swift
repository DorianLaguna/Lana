import Foundation

public extension Card {
    /// Empareja el texto de tarjeta que entrega el trigger de Wallet/Shortcuts
    /// (p. ej. "Nu Crédito Mastercard") contra las tarjetas dadas de alta en
    /// Lana. No hay forma de saber de antemano cómo Wallet nombra cada
    /// tarjeta del usuario, así que esto es una heurística, no un id exacto
    /// (ADR-0019).
    ///
    /// Prioridad: si el texto contiene los últimos 4 dígitos de alguna
    /// tarjeta, esa gana siempre — son los más específicos y casi nunca
    /// coinciden por accidente. Si no, cae a la tarjeta cuyo alias aparece
    /// como substring del texto (normalizando acentos/mayúsculas), y solo si
    /// es la única que calza — un texto que calza con dos alias a la vez no
    /// se resuelve solo, se reporta como ambiguo para que el usuario revise
    /// el nombre en Shortcuts o en Lana.
    static func bestMatch(for walletText: String, in cards: [Card]) -> Card? {
        let normalizedText = walletText.foldedForMatching

        let byLastFour = cards.filter { card in
            guard let lastFour = card.lastFourDigits else { return false }
            return normalizedText.contains(lastFour)
        }
        if byLastFour.count == 1 {
            return byLastFour[0]
        }

        let byAlias = cards.filter { normalizedText.contains($0.alias.foldedForMatching) }
        if byAlias.count == 1 {
            return byAlias[0]
        }

        return nil
    }
}

private extension String {
    var foldedForMatching: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

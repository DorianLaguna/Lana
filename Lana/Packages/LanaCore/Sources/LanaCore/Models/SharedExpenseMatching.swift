import Foundation

/// El resultado de resolver `ParseResult.payerHint`/`splitHint` contra las
/// listas compartidas reales del usuario — a qué lista, quién pagó, y con
/// qué regla se divide (ADR-0025).
public struct SharedExpenseMatch: Sendable, Hashable {
    public let sharedListID: SharedListID
    public let payer: ParticipantID
    public let split: SplitRule

    public init(sharedListID: SharedListID, payer: ParticipantID, split: SplitRule) {
        self.sharedListID = sharedListID
        self.payer = payer
        self.split = split
    }
}

public extension SharedExpenseMatch {
    /// Resuelve `payerHint` contra el roster de todas las listas compartidas
    /// del usuario. `nil` si `payerHint` está vacío (no hay señal de que el
    /// gasto sea compartido — la mayoría de las capturas son personales), o
    /// si el nombre calza con 2+ participantes en listas distintas (o
    /// ninguno) — ambiguo se trata igual que "no encontrado", nunca se
    /// adivina con quién se comparte dinero real (mismo criterio que
    /// `Card.bestMatch`, ADR-0019).
    ///
    /// "yo" resuelve contra la identidad del propio dispositivo en cada
    /// lista (`viewerIdentities`, ADR-0022) — sin esa marca puesta en una
    /// lista, "yo" no calza ahí y esa lista queda fuera de la búsqueda.
    static func bestMatch(
        payerHint: String,
        splitHint: String?,
        in lists: [SharedList],
        viewerIdentities: [SharedListID: ParticipantID]) -> SharedExpenseMatch? {
        let normalizedHint = payerHint.foldedForMatching
        guard !normalizedHint.isEmpty else { return nil }

        let candidates: [(list: SharedList, payer: ParticipantID)] = lists.compactMap { list in
            if normalizedHint == "yo", let viewerID = viewerIdentities[list.id] {
                return (list, viewerID)
            }
            let matches = list.participants.filter { $0.displayName.foldedForMatching == normalizedHint }
            guard matches.count == 1 else { return nil }
            return (list, matches[0].id)
        }
        guard candidates.count == 1, let candidate = candidates.first else { return nil }

        return SharedExpenseMatch(
            sharedListID: candidate.list.id,
            payer: candidate.payer,
            split: resolvedSplit(from: splitHint, list: candidate.list))
    }

    /// "igual"/variantes → partes iguales entre todo el roster vigente;
    /// "yo"/variantes → nadie más debe nada de este gasto; cualquier otra
    /// cosa (una proporción o porcentaje descrito en texto libre, o nada
    /// mencionado) cae al `preferredSplit` de la lista — proporcional si
    /// tiene los ingresos capturados (ADR-0028), si no su `defaultSplit`.
    ///
    /// Usaba `defaultSplit` directo, y eso dejaba fuera el proporcional
    /// justo en el camino donde más se usa (ADR-0030): capturar por voz
    /// caía siempre en partes iguales aunque la lista tuviera ingresos.
    ///
    /// Parsear una proporción arbitraria de un string libre con confianza
    /// suficiente para dividir dinero real sigue fuera de alcance
    /// (ADR-0025); ese caso se resuelve a mano en `SharedExpenseCaptureView`.
    private static func resolvedSplit(from splitHint: String?, list: SharedList) -> SplitRule {
        switch splitHint?.foldedForMatching {
        case "igual", "partes iguales", "mitad", "a la mitad":
            .equally(among: list.participants.map(\.id))
        case "yo", "solo", "yo solo":
            .payerOnly
        default:
            list.preferredSplit
        }
    }
}

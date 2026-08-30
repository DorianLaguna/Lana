import Foundation

/// Cuánto le toca a un participante de un gasto compartido — el desglose
/// que hay detrás de "tu parte" (ADR-0029). Presentación pura: no se
/// persiste, se deriva del `SplitRule` congelado en el evento.
public struct SplitShare: Sendable, Hashable, Identifiable {
    public let participant: ParticipantID
    public let amount: Money
    /// `true` para quien pagó — se marca aparte porque pagar y deber son
    /// cosas distintas: quien pagó puso el total y le deben la diferencia.
    public let isPayer: Bool

    public var id: ParticipantID {
        participant
    }

    public init(participant: ParticipantID, amount: Money, isPayer: Bool) {
        self.participant = participant
        self.amount = amount
        self.isPayer = isPayer
    }
}

public extension SplitRule {
    /// Cómo se llama esta regla en la UI. Vive aquí y no en una feature
    /// porque tres pantallas de dos módulos distintos la muestran
    /// (`SharedExpenseCaptureView`, `EditExpenseView`, `DraftCard`) y las
    /// features no se importan entre sí — mismo criterio que
    /// `SuggestedCategory.displayName`.
    /// Una sola tabla de nombres, la de `SplitRuleKind` — es la misma regla
    /// con y sin sus números, y tenerla dos veces dejaba que una se
    /// renombrara sin la otra, mostrando nombres distintos para lo mismo
    /// según la pantalla.
    var displayName: String {
        SplitRuleKind(self).displayName
    }
}

public extension Expense {
    /// El desglose de cuánto le toca a cada quien, ordenado con quien pagó
    /// primero. `nil` si el gasto no es compartido, o si el split guardado
    /// no resuelve (participaciones inválidas) — el llamador muestra el
    /// gasto sin desglose en vez de un desglose inventado.
    ///
    /// `.payerOnly` es el caso especial, igual que en
    /// `Expense.personalAmount`: `portions(of:)` regresa vacío porque nadie
    /// le debe nada a nadie, pero para mostrarlo sí importa decir que el
    /// total le tocó a quien pagó.
    func splitShares() -> [SplitShare]? {
        guard sharedListID != nil, let split else { return nil }

        if case .payerOnly = split {
            guard let payer else { return nil }
            return [SplitShare(participant: payer, amount: amount, isPayer: true)]
        }

        guard let portions = try? split.portions(of: amount) else { return nil }
        return portions
            .map { SplitShare(participant: $0.key, amount: $0.value, isPayer: $0.key == payer) }
            .sorted { lhs, rhs in
                if lhs.isPayer != rhs.isPayer {
                    return lhs.isPayer
                }
                return lhs.participant < rhs.participant
            }
    }
}

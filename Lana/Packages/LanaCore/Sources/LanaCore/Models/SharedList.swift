import Foundation

/// Una lista de gastos compartidos entre participantes.
public struct SharedList: Sendable, Hashable, Identifiable, Codable {
    public let id: SharedListID
    public var name: String
    /// El roster completo, no solo los IDs — antes de que exista identidad
    /// real de CKShare (Fase 8, G3), el nombre para mostrar de cada
    /// participante no vive en ningún otro lado más que aquí.
    public var participants: [Participant]
    /// La regla de división vigente. Se usa para pre-llenar el registro de un
    /// gasto nuevo — lo que se guarda en cada evento son las participaciones
    /// concretas de ese momento, no una referencia a esto (ADR-0007).
    public var defaultSplit: SplitRule

    public init(
        id: SharedListID = SharedListID(),
        name: String,
        participants: [Participant],
        defaultSplit: SplitRule) {
        self.id = id
        self.name = name
        self.participants = participants
        self.defaultSplit = defaultSplit
    }
}

public extension SharedList {
    /// La división proporcional derivada de los ingresos capturados
    /// (`Participant.monthlyIncome`), normalizados para sumar exactamente 1
    /// — `SplitRule.portions(of:)` rechaza cualquier otra cosa. `nil` si
    /// alguien no tiene ingreso capturado o si suman 0: dividir
    /// proporcionalmente sin saber las proporciones no se adivina.
    ///
    /// El residuo del redondeo se le da al último participante por orden de
    /// `ParticipantID` — ver `ProportionalShares.normalized(weights:among:)`,
    /// que es de donde sale la normalización y la comparte con la captura a
    /// mano del formulario completo, para que los mismos ingresos no
    /// congelen centavos distintos según por dónde se haya entrado.
    var proportionalSplitFromIncomes: SplitRule? {
        let incomes = participants.compactMap(\.monthlyIncome)
        guard incomes.count == participants.count else { return nil }
        guard incomes.reduce(Decimal(0), +) > 0 else { return nil }

        var weights: [ParticipantID: Decimal] = [:]
        for participant in participants {
            weights[participant.id] = participant.monthlyIncome ?? 0
        }
        return .proportional(
            shares: ProportionalShares.normalized(weights: weights, among: participants.map(\.id)))
    }

    /// Con qué regla pre-llenar un gasto nuevo: proporcional si la lista
    /// tiene los ingresos capturados (lo pedido por el usuario como default),
    /// si no el `defaultSplit` guardado. Nunca falla — siempre hay una regla
    /// con la cual capturar.
    var preferredSplit: SplitRule {
        proportionalSplitFromIncomes ?? defaultSplit
    }

    /// El nombre a mostrar de un participante, con "Yo" en lugar del nombre
    /// propio — pedido explícito del usuario ("cuando yo digo que soy una
    /// persona, entonces debería aparecer como 'yo'"). Es solo presentación:
    /// el roster sigue guardando el nombre real, que es lo que ve la otra
    /// persona en su dispositivo.
    ///
    /// Vive aquí y no en cada feature porque tres módulos lo muestran
    /// (`SharedListDetailModel`, `EditExpenseModel`, `EntryModel`) y las
    /// features no se importan entre sí — mismo criterio que
    /// `SplitRule.displayName`. Con una copia por módulo, cambiar el texto
    /// en uno dejaba los otros dos diciendo otra cosa.
    ///
    /// - Parameter viewer: quién es "yo" en esta lista (ADR-0022). `nil`
    ///   mientras no se haya marcado: entonces nadie es "yo" y todos salen
    ///   con su nombre real.
    func displayName(for id: ParticipantID, viewer: ParticipantID?) -> String {
        if id == viewer {
            return "Yo"
        }
        return participants.first { $0.id == id }?.displayName ?? "Alguien"
    }
}

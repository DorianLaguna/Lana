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

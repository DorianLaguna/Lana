/// Alguien que participa en una `SharedList`.
public struct Participant: Sendable, Hashable, Identifiable, Codable {
    public let id: ParticipantID
    public var displayName: String

    public init(id: ParticipantID = ParticipantID(), displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

import Foundation

public struct Participant: Sendable, Hashable, Identifiable, Codable {
    public let id: ParticipantID
    public var displayName: String
    /// Cuánto gana esta persona, para dividir proporcionalmente sin tener
    /// que teclear la proporción en cada gasto (ADR-0028). `nil` = no se
    /// capturó; una lista donde alguien lo tenga en `nil` no puede dividir
    /// proporcional y cae a partes iguales (`SharedList.preferredSplit`).
    ///
    /// Es un dato de la lista, no del gasto: lo que se guarda en cada evento
    /// son las participaciones ya resueltas de ese momento (ADR-0007), así
    /// que cambiar un ingreso aquí aplica hacia adelante y nunca recalcula
    /// el historial.
    ///
    /// `Optional` a propósito: `Participant` se serializa como JSON dentro de
    /// `CDSharedList.participantsData`, y el `Codable` sintetizado usa
    /// `decodeIfPresent` para opcionales — las listas creadas antes de que
    /// esto existiera siguen decodificando, con `nil`.
    public var monthlyIncome: Decimal?

    public init(id: ParticipantID = ParticipantID(), displayName: String, monthlyIncome: Decimal? = nil) {
        self.id = id
        self.displayName = displayName
        self.monthlyIncome = monthlyIncome
    }
}

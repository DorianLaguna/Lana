import Foundation

/// Un identificador tipado. El parámetro fantasma `Tag` evita mezclar, por
/// ejemplo, un `ParticipantID` con un `CardID` por accidente — el compilador
/// lo impide.
public struct Identifier<Tag>: Sendable, Hashable, Codable, RawRepresentable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

extension Identifier: Comparable {
    public static func < (lhs: Identifier, rhs: Identifier) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }
}

public enum ParticipantTag: Sendable {}
/// Identifica a un participante de una lista compartida.
public typealias ParticipantID = Identifier<ParticipantTag>

public enum SharedListTag: Sendable {}
/// Identifica una lista compartida.
public typealias SharedListID = Identifier<SharedListTag>

public enum CardTag: Sendable {}
/// Identifica una tarjeta.
public typealias CardID = Identifier<CardTag>

public enum ExpenseTag: Sendable {}
/// Identifica un `Expense` en el modelo de lectura (`ExpenseStore`).
public typealias ExpenseID = Identifier<ExpenseTag>

public enum EventTag: Sendable {}
/// Identifica un evento del ledger (`ExpenseEvent`).
public typealias EventID = Identifier<EventTag>

public enum RecurringItemTag: Sendable {}
/// Identifica un ingreso o gasto recurrente (`RecurringItem`).
public typealias RecurringItemID = Identifier<RecurringItemTag>

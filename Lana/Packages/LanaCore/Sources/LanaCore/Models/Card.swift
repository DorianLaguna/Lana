import Foundation

/// Crédito o débito — se fija al dar de alta o editar la tarjeta, no se
/// adivina por transacción. Antes se intentaba inferir del texto de cada
/// captura ("con crédito", "con débito"), pero decir "con la tarjeta X" sin
/// esa palabra dejaba la tarjeta sin resolver — la tarjeta ya sabe qué es.
public enum CardKind: String, Sendable, Hashable, Codable, CaseIterable {
    case credit
    case debit
}

/// Una tarjeta de crédito o débito. **Nunca** guarda el número completo, CVV
/// ni fecha de vencimiento — alias y últimos cuatro alcanzan para todo lo que
/// hace la app (Docs/CLAUDE.md).
public struct Card: Sendable, Hashable, Identifiable, Codable {
    public let id: CardID
    public var alias: String
    /// `nil` si el usuario no los capturó — no son obligatorios para dar de
    /// alta una tarjeta. Cuando sí vienen, tienen que ser exactamente 4
    /// dígitos.
    public var lastFourDigits: String?
    /// `nil` en una tarjeta de débito — no tiene línea de crédito. Solo las
    /// de crédito la requieren.
    public var limit: Money?
    /// `nil` en una tarjeta de débito — no tiene estado de cuenta ni corte.
    /// Solo las de crédito lo requieren.
    public var cutoffDay: Int?
    /// `nil` en una tarjeta de débito — no tiene fecha límite de pago. Solo
    /// las de crédito lo requieren.
    public var dueDay: Int?
    public var kind: CardKind
    /// Hex (`#RRGGBB`) para distinguirla de las demás en las listas — el
    /// usuario lo elige, no se deriva.
    public var colorHex: String

    public init(
        id: CardID = CardID(),
        alias: String,
        lastFourDigits: String,
        limit: Money?,
        cutoffDay: Int?,
        dueDay: Int?,
        kind: CardKind = .credit,
        colorHex: String = "#1B4FD8") throws {
        let trimmedLastFourDigits = lastFourDigits.trimmingCharacters(in: .whitespaces)
        if trimmedLastFourDigits.isEmpty {
            self.lastFourDigits = nil
        } else if trimmedLastFourDigits.count == 4, trimmedLastFourDigits.allSatisfy(\.isNumber) {
            self.lastFourDigits = trimmedLastFourDigits
        } else {
            throw CardError.invalidLastFourDigits(lastFourDigits)
        }
        self.id = id
        self.alias = alias
        self.kind = kind
        self.colorHex = colorHex
        // El débito no tiene línea de crédito, corte ni fecha límite de
        // pago en la realidad — sea lo que sea que se haya capturado para
        // esos campos, no aplica y no se guarda.
        if kind == .credit {
            guard let cutoffDay, (1 ... 31).contains(cutoffDay) else {
                throw CardError.invalidCutoffDay(cutoffDay ?? 0)
            }
            guard let dueDay, (1 ... 31).contains(dueDay) else {
                throw CardError.invalidDueDay(dueDay ?? 0)
            }
            guard let limit else {
                throw CardError.missingLimit
            }
            self.limit = limit
            self.cutoffDay = cutoffDay
            self.dueDay = dueDay
        } else {
            self.limit = nil
            self.cutoffDay = nil
            self.dueDay = nil
        }
    }
}

public enum CardError: LocalizedError, Sendable {
    case invalidLastFourDigits(String)
    case invalidCutoffDay(Int)
    case invalidDueDay(Int)
    case missingLimit

    public var errorDescription: String? {
        switch self {
        case let .invalidLastFourDigits(value):
            "«\(value)» no son cuatro dígitos válidos."
        case let .invalidCutoffDay(day):
            "\(day) no es un día de corte válido (1-31)."
        case let .invalidDueDay(day):
            "\(day) no es una fecha límite válida (1-31)."
        case .missingLimit:
            "Falta el límite de crédito."
        }
    }
}

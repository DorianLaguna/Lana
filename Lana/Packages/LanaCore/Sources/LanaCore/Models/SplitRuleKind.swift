import Foundation

/// Las 5 formas de dividir un gasto, sin los valores concretos — el "qué
/// regla" separado del "con qué números". Vive en `LanaCore` y no en una
/// feature porque tres pantallas de tres módulos distintos ofrecen este
/// picker (`SharedExpenseCaptureView`, `EditExpenseView`, `DraftCard`) y las
/// features no se importan entre sí (ADR-0030).
public enum SplitRuleKind: String, CaseIterable, Identifiable, Sendable {
    case proportional
    case equally
    case payerOnly
    case percentage
    case exactAmounts

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .proportional: "Proporcional"
        case .equally: "Partes iguales"
        case .payerOnly: "Solo quien pagó"
        case .percentage: "Porcentaje"
        case .exactAmounts: "Montos exactos"
        }
    }

    /// Si necesita que el usuario capture un número por participante.
    /// `.equally`/`.payerOnly` se resuelven solas contra el roster, y
    /// `.proportional` se resuelve sola **si la lista ya tiene los ingresos
    /// capturados** (ADR-0028) — por eso no está aquí: depende de la lista,
    /// no de la regla. Ver `SplitRuleKind.resolve(in:)`.
    public var needsPerParticipantInput: Bool {
        switch self {
        case .equally, .payerOnly: false
        case .proportional, .percentage, .exactAmounts: true
        }
    }

    public init(_ split: SplitRule) {
        switch split {
        case .equally: self = .equally
        case .payerOnly: self = .payerOnly
        case .proportional: self = .proportional
        case .percentage: self = .percentage
        case .exactAmounts: self = .exactAmounts
        }
    }

    /// La regla concreta que sale de esta opción con los datos que la lista
    /// ya tiene o con valores por defecto (ej. partes iguales de porcentaje o del monto).
    public func resolve(in list: SharedList, amount: Decimal = 0) -> SplitRule? {
        let ids = list.participants.map(\.id)
        guard !ids.isEmpty else { return nil }
        switch self {
        case .equally:
            return .equally(among: ids)
        case .payerOnly:
            return .payerOnly
        case .proportional:
            return list.proportionalSplitFromIncomes ?? list.fallbackProportionalSplit
        case .percentage:
            if let proportional = list.proportionalSplitFromIncomes,
               case let .proportional(shares) = proportional {
                let percentageShares = shares.mapValues { ($0 * 100).rounded(scale: 2, mode: .down) }
                return .percentage(shares: percentageShares)
            }
            let n = Decimal(ids.count)
            let basePercentage = (Decimal(100) / n).rounded(scale: 2, mode: .down)
            var shares: [ParticipantID: Decimal] = [:]
            var sum = Decimal(0)
            let sorted = ids.sorted()
            for id in sorted.dropLast() {
                shares[id] = basePercentage
                sum += basePercentage
            }
            if let last = sorted.last {
                shares[last] = 100 - sum
            }
            return .percentage(shares: shares)
        case .exactAmounts:
            let n = Decimal(ids.count)
            let baseAmount = (amount / n).rounded(scale: 2, mode: .down)
            var amounts: [ParticipantID: Decimal] = [:]
            var sum = Decimal(0)
            let sorted = ids.sorted()
            for id in sorted.dropLast() {
                amounts[id] = baseAmount
                sum += baseAmount
            }
            if let last = sorted.last {
                amounts[last] = amount - sum
            }
            return .exactAmounts(amounts: amounts)
        }
    }

    /// Las opciones que una lista puede resolver sola — las que tiene
    /// sentido ofrecer fuera del formulario completo de Compartido.
    public static func resolvable(in list: SharedList) -> [SplitRuleKind] {
        allCases.filter { $0.resolve(in: list) != nil }
    }
}

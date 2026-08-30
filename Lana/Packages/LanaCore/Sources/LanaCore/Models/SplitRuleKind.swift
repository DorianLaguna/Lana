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
    /// ya tiene, sin pedirle nada más al usuario. `nil` cuando hacen falta
    /// números que solo el formulario completo puede capturar
    /// (`.percentage`/`.exactAmounts`, o `.proportional` en una lista sin
    /// ingresos) — quien llama ofrece solo las opciones que sí resuelven.
    public func resolve(in list: SharedList) -> SplitRule? {
        switch self {
        case .equally: .equally(among: list.participants.map(\.id))
        case .payerOnly: .payerOnly
        case .proportional: list.proportionalSplitFromIncomes
        case .percentage, .exactAmounts: nil
        }
    }

    /// Las opciones que una lista puede resolver sola — las que tiene
    /// sentido ofrecer fuera del formulario completo de Compartido.
    public static func resolvable(in list: SharedList) -> [SplitRuleKind] {
        allCases.filter { $0.resolve(in: list) != nil }
    }
}

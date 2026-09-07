import Foundation

/// El resultado de validar un monto del modelo contra los números que
/// literalmente aparecen en el texto crudo.
public struct AmountValidation: Sendable, Equatable {
    public enum Source: Sendable, Equatable {
        /// El monto del modelo aparece tal cual en el texto.
        case model
        /// El monto del modelo no aparece en el texto; ganó el regex.
        case regex
        /// El texto no tiene ningún número reconocible — no se pudo
        /// validar, se deja pasar el monto del modelo.
        case unvalidated
    }

    public let amount: Decimal
    public let source: Source

    public var needsReview: Bool {
        source == .regex
    }
}

/// Valida montos por regex sobre el texto crudo. **Su resultado gana sobre
/// el modelo** (Docs/CLAUDE.md, Docs/.claude/skills/foundation-models):
/// el modelo ocasionalmente devuelve 30 donde el texto decía 300, o inventa
/// un cero de más. Nunca usa el modelo — es puro y determinista.
public struct AmountValidator: Sendable {
    public init() {}

    /// Todos los montos numéricos que aparecen literalmente en `text`, en el
    /// orden en que aparecen. Reconoce enteros, decimales con punto, y
    /// separador de miles con coma (`1,250.50`).
    public func amounts(in text: String) -> [Decimal] {
        // El primer grupo exige AL MENOS una coma de miles (`+`, no `*`) —
        // si no, "1000" se parte en "100" + "0" porque `\d{1,3}` se conforma
        // con 3 dígitos y el resto del grupo es opcional.
        let pattern = #"\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            let raw = text[matchRange].replacingOccurrences(of: ",", with: "")
            return Decimal(string: raw)
        }
    }

    /// Valida `modelAmount` contra los números de `text`. Si no coincide con
    /// ninguno pero el texto sí tiene números, gana el más cercano en valor
    /// a `modelAmount` — es la mejor aproximación disponible sin otra señal,
    /// y de todos modos queda marcada `needsReview`.
    public func validate(modelAmount: Decimal, in text: String) -> AmountValidation {
        let found = amounts(in: text)
        guard !found.isEmpty else {
            return AmountValidation(amount: modelAmount, source: .unvalidated)
        }
        if found.contains(modelAmount) {
            return AmountValidation(amount: modelAmount, source: .model)
        }
        let closest = found.min { lhs, rhs in
            abs(lhs - modelAmount) < abs(rhs - modelAmount)
        }
        // `found` no está vacío, así que `closest` siempre existe.
        return AmountValidation(amount: closest ?? modelAmount, source: .regex)
    }
}

public extension AmountValidator {
    /// El monto de una captura automática que puede llegar como número o
    /// como texto (ADR-0033). El numérico gana; el de texto es el respaldo
    /// para cuando quien invoca pierde el tipo por el camino — Shortcuts
    /// entrega 0 al meter una cantidad con moneda ("$149.99") en un campo
    /// `Double`, aun con el atajo bien armado.
    ///
    /// `nil` si ninguno trae un monto usable: quien llama lo reporta como
    /// error de configuración en vez de guardar un gasto de $0 — un gasto
    /// de monto ≤ 0 no existe, mismo criterio que `ParsingPipeline`.
    ///
    /// Del texto toma el PRIMER monto, no el mayor ni el más cercano a
    /// nada: el campo está documentado para recibir la variable de monto,
    /// no una frase. Nunca pasa por el modelo — el regex gana sobre el
    /// modelo en el monto (Docs/CLAUDE.md).
    func resolveAmount(numeric: Double, text: String?) -> Decimal? {
        if numeric > 0 {
            // `Decimal(a Double)` es la conversión binaria exacta del
            // `Double`, no del decimal que se esperaría — la misma trampa
            // que `Money.swift` documenta para literales. Redondear a
            // centavos vía texto evita que 149.99 llegue como
            // 149.98999999999998.
            return Decimal(string: String(format: "%.2f", numeric)) ?? Decimal(numeric)
        }
        guard let text, let first = amounts(in: text).first, first > 0 else { return nil }
        return first
    }
}

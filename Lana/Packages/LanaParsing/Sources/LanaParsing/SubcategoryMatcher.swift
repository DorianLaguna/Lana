import Foundation

/// Resuelve la subcategoría propuesta por el modelo contra las que el
/// usuario ya tiene en esa categoría, por distancia de Levenshtein
/// (ADR-0011). Sin un umbral calibrado por longitud, "gasolina" y
/// "gasolinas" se vuelven dos subcategorías distintas.
public struct SubcategoryMatcher: Sendable {
    public init() {}

    /// Nombres que nunca son subcategorías válidas — si el modelo propone
    /// uno de estos (o el campo viene vacío), el resultado es `nil`: la
    /// subcategoría queda sin asignar en vez de contaminar el vocabulario
    /// con algo genérico (ADR-0011).
    private static let invalidNames: Set = [
        "otro", "otros", "otra", "otras", "varios", "varias", "misc", "miscelaneo", "miscelaneos"
    ]

    /// - Returns: el nombre existente si `proposed` se parece lo suficiente
    ///   a alguno; `proposed` tal cual si no se parece a ninguno (se crea);
    ///   `nil` si `proposed` no es un nombre válido.
    public func resolve(_ proposed: String, existing: [String]) -> String? {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Self.invalidNames.contains(trimmed.lowercased()) else {
            return nil
        }

        for candidate in existing where similarity(trimmed, candidate) >= threshold(for: trimmed) {
            return candidate
        }
        return trimmed
    }

    /// Entre más corto el nombre, un solo carácter distinto pesa más — el
    /// umbral sube con la longitud para no exigir una coincidencia perfecta
    /// en nombres largos ni ser laxo en nombres cortos.
    private func threshold(for text: String) -> Double {
        switch text.count {
        case ..<4: 0.9
        case 4 ..< 8: 0.8
        default: 0.75
        }
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        let normalizedLhs = lhs.lowercased()
        let normalizedRhs = rhs.lowercased()
        let maxLength = max(normalizedLhs.count, normalizedRhs.count)
        guard maxLength > 0 else { return 1 }
        let distance = levenshteinDistance(normalizedLhs, normalizedRhs)
        return 1 - Double(distance) / Double(maxLength)
    }

    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        if lhsChars.isEmpty {
            return rhsChars.count
        }
        if rhsChars.isEmpty {
            return lhsChars.count
        }

        var previousRow = Array(0 ... rhsChars.count)
        var currentRow = [Int](repeating: 0, count: rhsChars.count + 1)

        for rowIndex in 1 ... lhsChars.count {
            currentRow[0] = rowIndex
            for columnIndex in 1 ... rhsChars.count {
                let cost = lhsChars[rowIndex - 1] == rhsChars[columnIndex - 1] ? 0 : 1
                currentRow[columnIndex] = min(
                    previousRow[columnIndex] + 1,
                    currentRow[columnIndex - 1] + 1,
                    previousRow[columnIndex - 1] + cost)
            }
            previousRow = currentRow
        }
        return previousRow[rhsChars.count]
    }
}

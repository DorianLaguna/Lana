import Foundation
import LanaCore

/// Lo que quedó dudoso en un borrador (rediseño, sección 08). Se dibuja como
/// un chip en `attention`, y **nunca bloquea guardar**: el movimiento entra
/// igual y queda por revisar (Docs/CLAUDE.md → "Guardar nunca se bloquea").
public enum DraftDoubt: String, Equatable, Sendable, Identifiable, CaseIterable {
    /// El parser no encontró monto, o quedó en cero.
    case amount
    /// No se entendió qué se compró.
    case concept
    /// Un gasto sin categoría.
    case category
    /// El parser sí llenó los campos pero no tuvo certeza — el monto que
    /// discrepó del regex (`AmountValidator`), un compartido sin lista única.
    case uncertain

    public var id: String {
        rawValue
    }

    /// El texto del chip. Dice qué falta, sin regañar.
    public var label: String {
        switch self {
        case .amount: "Falta el monto"
        case .concept: "Falta el concepto"
        case .category: "Falta la categoría"
        case .uncertain: "Revisa que esté bien"
        }
    }
}

public extension DraftTransaction {
    /// Qué le falta a este borrador, en el orden en que se lee la tarjeta.
    ///
    /// `uncertain` solo aparece cuando no hay una duda más concreta: si ya se
    /// dice que falta el monto, repetir "revisa que esté bien" es ruido.
    var doubts: [DraftDoubt] {
        var doubts: [DraftDoubt] = []
        if amount <= 0 {
            doubts.append(.amount)
        }
        if concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            doubts.append(.concept)
        }
        if kind == .expense, category.isEmpty {
            doubts.append(.category)
        }
        if needsReview, doubts.isEmpty {
            doubts.append(.uncertain)
        }
        return doubts
    }
}

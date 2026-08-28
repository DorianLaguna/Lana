import CoreData
import Foundation
import LanaCore

/// `CorrectionVocabularyStore` respaldado por Core Data — mismo actor,
/// mismo container que `ExpenseStore` (ADR-0014). El vocabulario aprendido
/// es la última corrección conocida por término, no un log — `record` es un
/// upsert.
extension CoreDataExpenseStore: CorrectionVocabularyStore {
    public func record(term: String, category: String) async {
        try? await context.perform { [context] in
            let key = Self.normalize(term)
            if let row = try Self.existingVocabularyRow(for: key, in: context) {
                row.useCount = row.category == category ? row.useCount + 1 : 1
                row.category = category
                row.correctedAt = Date()
            } else {
                let row = CDVocabularyEntry(context: context)
                row.term = term
                row.category = category
                row.correctedAt = Date()
                row.useCount = 1
            }
            try Self.saveIfNeeded(context)
        }
    }

    public func topEntries(limit: Int) async -> [CorrectionEntry] {
        await (try? context.perform { [context] in
            let rows = try context.fetch(CDVocabularyEntry.fetchRequest())
            return rows.compactMap(Self.entry(from:))
                .sorted { lhs, rhs in
                    lhs.useCount == rhs.useCount ? lhs.correctedAt > rhs.correctedAt : lhs.useCount > rhs.useCount
                }
                .prefix(limit)
                .map(\.self)
        }) ?? []
    }

    public func allEntries() async -> [CorrectionEntry] {
        await (try? context.perform { [context] in
            let rows = try context.fetch(CDVocabularyEntry.fetchRequest())
            return rows.compactMap(Self.entry(from:))
                .sorted { $0.useCount == $1.useCount ? $0.term < $1.term : $0.useCount > $1.useCount }
        }) ?? []
    }

    public func delete(term: String) async {
        try? await context.perform { [context] in
            guard let row = try Self.existingVocabularyRow(for: Self.normalize(term), in: context) else { return }
            context.delete(row)
            try Self.saveIfNeeded(context)
        }
    }

    public func deleteAll() async {
        try? await context.perform { [context] in
            let rows = try context.fetch(CDVocabularyEntry.fetchRequest())
            rows.forEach(context.delete)
            try Self.saveIfNeeded(context)
        }
    }

    /// Filtra en Swift (no con un `NSPredicate`) para que "normalizar" sea
    /// exactamente la misma función que usa `InMemoryCorrectionVocabularyStore`
    /// — recortar espacios y pasar a minúsculas, no solo case-insensitive.
    private static func existingVocabularyRow(
        for normalizedTerm: String,
        in context: NSManagedObjectContext) throws -> CDVocabularyEntry? {
        try context.fetch(CDVocabularyEntry.fetchRequest())
            .first { row in row.term.map(Self.normalize) == normalizedTerm }
    }

    private static func entry(from row: CDVocabularyEntry) -> CorrectionEntry? {
        guard let term = row.term, let category = row.category, let correctedAt = row.correctedAt else { return nil }
        return CorrectionEntry(term: term, category: category, correctedAt: correctedAt, useCount: Int(row.useCount))
    }

    private static func normalize(_ term: String) -> String {
        term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

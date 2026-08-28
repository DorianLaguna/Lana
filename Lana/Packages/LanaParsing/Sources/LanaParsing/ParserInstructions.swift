import Foundation
import LanaCore

/// Construye las instrucciones de la sesión. **Nunca contienen cifras,
/// montos ni frases completas de ejemplo** (ADR-0013) — un ejemplo con un
/// monto se filtró a las respuestas de frases que no lo mencionaban y tumbó
/// la accuracy de conteo a 13% en el spike. Solo reglas abstractas y listas
/// de etiquetas (nombres de subcategoría, términos aprendidos, alias de
/// tarjeta) — eso sí es vocabulario de salida, seguro de incluir.
public enum ParserInstructions {
    /// Arma las instrucciones a partir del vocabulario del usuario — cada
    /// sección es opcional y solo aparece si trae contenido.
    public static func build(
        subcategoriesByCategory: [ExpenseCategory: [String]] = [:],
        correctionVocabulary: [CorrectionEntry] = [],
        cardAliases: [String] = []) -> String {
        var sections: [String] = [base]

        if !subcategoriesByCategory.isEmpty {
            sections.append(subcategorySection(subcategoriesByCategory))
        }
        if !correctionVocabulary.isEmpty {
            sections.append(vocabularySection(correctionVocabulary))
        }
        if !cardAliases.isEmpty {
            sections.append(cardSection(cardAliases))
        }

        return sections.joined(separator: "\n\n")
    }

    private static let base = """
    Extraes transacciones financieras (gastos e ingresos) de frases en \
    español mexicano coloquial, dichas o escritas por una sola persona sobre \
    su propio dinero.

    El texto de entrada no siempre describe una transacción real — puede \
    ser una prueba, un saludo, ruido de transcripción, o algo sin relación \
    con dinero. Si el texto no describe con claridad una compra, un cobro o \
    un ingreso real, la lista de transacciones debe quedar vacía. Nunca \
    inventes un monto, un concepto o una categoría para algo que no fue \
    descrito — es preferible no proponer nada a proponer algo que no se dijo.

    Las siguientes secciones (si aparecen) son listas de nombres que esa \
    persona ya usa — subcategorías, tarjetas — para que reutilices sus \
    términos en vez de inventar variantes. No son datos de la frase actual: \
    nunca copies un nombre de esas listas a tu respuesta a menos que \
    realmente corresponda a lo que dice el texto de entrada.
    """

    private static func subcategorySection(_ bySubcategory: [ExpenseCategory: [String]]) -> String {
        let lines = ExpenseCategory.allCases.compactMap { category -> String? in
            guard let names = bySubcategory[category], !names.isEmpty else { return nil }
            return "- \(category.rawValue): " + names.joined(separator: ", ")
        }
        return """
        Subcategorías que la persona ya tiene, por categoría — cuando el \
        texto describe algo que corresponde a una de estas, en la \
        categoría correspondiente, propón ese nombre exacto en vez de uno \
        nuevo:
        \(lines.joined(separator: "\n"))
        """
    }

    private static func vocabularySection(_ entries: [CorrectionEntry]) -> String {
        let lines = entries.map { "\($0.term) → \($0.category)" }
        return "Términos que esta persona corrigió antes (término → categoría):\n" + lines.joined(separator: "\n")
    }

    private static func cardSection(_ aliases: [String]) -> String {
        "Alias de tarjetas que la persona ya tiene: " + aliases.joined(separator: ", ")
    }
}

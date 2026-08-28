import LanaCore
import Testing
@testable import LanaParsing

/// La regresión que motivó ADR-0013: un ejemplo con "460" en las
/// instrucciones se filtró a respuestas de frases que no lo mencionaban y
/// tumbó la accuracy de conteo a 13%. Esta suite garantiza que las
/// instrucciones nunca contienen dígitos, sin importar qué vocabulario se
/// inyecte.
@Suite("ParserInstructions — ADR-0013")
struct ParserInstructionsTests {
    @Test("Las instrucciones base no tienen dígitos")
    func instruccionesBaseSinDigitos() {
        let instructions = ParserInstructions.build()
        #expect(!instructions.contains { $0.isNumber })
    }

    @Test("Las instrucciones con subcategorías, vocabulario y tarjetas siguen sin dígitos")
    func instruccionesConVocabularioSinDigitos() {
        let instructions = ParserInstructions.build(
            subcategoriesByCategory: [.ocio: ["hiking", "camping"], .comida: ["antojitos"]],
            correctionVocabulary: [
                CorrectionEntry(term: "bocina", category: "ocio"),
                CorrectionEntry(term: "chicles", category: "despensa")
            ],
            cardAliases: ["la Nu", "la azul"])
        #expect(!instructions.contains { $0.isNumber })
    }

    @Test("Las instrucciones incluyen el vocabulario inyectado")
    func instruccionesIncluyenVocabulario() {
        let instructions = ParserInstructions.build(
            subcategoriesByCategory: [.ocio: ["hiking"]],
            correctionVocabulary: [CorrectionEntry(term: "bocina", category: "ocio")],
            cardAliases: ["la Nu"])
        #expect(instructions.contains("hiking"))
        #expect(instructions.contains("bocina → ocio"))
        #expect(instructions.contains("la Nu"))
    }
}

import Foundation
import LanaCore
import Testing
@testable import LanaInsights

/// Calca `LanaParsingTests/ParserInstructionsTests`: la regla de ADR-0013 vale
/// igual para el análisis que para el parser. Un ejemplo con un monto dentro de
/// las instrucciones se filtró a las respuestas de frases que no lo mencionaban
/// y tumbó la accuracy de conteo a 13% — la firma inconfundible de esa
/// regresión es una cifra que aparece donde no la pidieron.
@Suite("Las instrucciones de análisis no llevan datos (ADR-0013)")
struct NarrationInstructionsTests {
    private let instructions: [String] = [
        NarrationInstructions.narration(),
        NarrationInstructions.recommendation(),
        ClassifierInstructions.build()
    ]

    @Test("Ninguna instrucción contiene un solo dígito")
    func ningunaInstruccionContieneDigitos() {
        for text in instructions {
            let digits = text.unicodeScalars.filter(CharacterSet.decimalDigits.contains)
            #expect(digits.isEmpty, "Una instrucción trae cifras: \(String(String.UnicodeScalarView(digits)))")
        }
    }

    @Test("Ninguna instrucción trae símbolo de moneda ni porcentaje")
    func ningunaInstruccionTraeMonedaNiPorcentaje() {
        for text in instructions {
            #expect(!text.contains("$"))
            #expect(!text.contains("%"))
        }
    }

    @Test("Cada instrucción declara que no contiene datos del usuario")
    func cadaInstruccionDeclaraQueNoTraeDatos() {
        for text in instructions {
            #expect(text.contains("no contiene datos del usuario"))
        }
    }

    @Test("Las instrucciones de narración prohíben calcular explícitamente")
    func lasInstruccionesProhibenCalcular() {
        let text = NarrationInstructions.narration()
        #expect(text.contains("No sumes"))
        #expect(text.contains("no saques porcentajes"))
    }

    @Test("Las instrucciones llevan el tono del producto: Lana no regaña")
    func lasInstruccionesLlevanElTono() {
        for text in [NarrationInstructions.narration(), NarrationInstructions.recommendation()] {
            #expect(text.contains("Lana no regaña") || text.contains("no regaña"))
            #expect(text.contains("deberías"))
        }
    }

    @Test("La guía de los grupos describe los tres, sin cifras")
    func laGuiaDeLosGruposDescribeLosTres() {
        let guide = BudgetGroupLabel.guideDescription
        for group in BudgetGroupLabel.allCases {
            #expect(guide.contains(group.rawValue))
        }
        #expect(guide.rangeOfCharacter(from: .decimalDigits) == nil)
    }

    @Test("El espejo de BudgetGroup no se desincronizó de LanaCore")
    func elEspejoDeBudgetGroupNoSeDesincronizo() {
        #expect(BudgetGroupLabel.allCases.map(\.rawValue).sorted()
            == BudgetGroup.allCases.map(\.rawValue).sorted())
    }
}

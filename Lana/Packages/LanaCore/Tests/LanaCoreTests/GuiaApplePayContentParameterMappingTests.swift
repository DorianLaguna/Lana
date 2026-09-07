import Foundation
import Testing
@testable import LanaCore

/// El mapeo de parámetros de la guía contra `AddTransactionIntent`.
///
/// La versión anterior probaba `intentParameter == walletParameter` — cierto
/// por construcción, con el literal 20 líneas más arriba en el mismo repo — y
/// además afirmaba `mappings.count == allCases.count` sobre un enum de tres
/// casos, lo que **congelaba** el mapeo incompleto: agregar los campos de
/// respaldo de ADR-0033 rompía el test. Una suite cuyo efecto neto era
/// encarecer la corrección del bug que la guía tenía.
///
/// Lo que sí se puede afirmar sin repetir el literal: que cada campo del
/// intent tenga su mapeo (nadie olvidó uno al agregar un caso), que ningún
/// campo aparezca dos veces, y la decisión de ADR-0033 de que una sola
/// variable de Wallet alimente dos campos.
@Suite("GuiaApplePayContent — mapeo de parámetros")
struct GuiaApplePayContentParameterMappingTests {
    private let mappings = GuiaApplePayContent.standard.parameterMappings

    @Test("Cada campo del intent tiene exactamente un mapeo", arguments: ParameterMapping.Parameter.allCases)
    func cadaCampoTieneExactamenteUnMapeo(parameter: ParameterMapping.Parameter) {
        #expect(mappings.filter { $0.intentParameter == parameter }.count == 1)
    }

    @Test("No sobran mapeos ni se repite un campo")
    func noSobranMapeosNiSeRepiteUnCampo() {
        let intentParameters = mappings.map(\.intentParameter)
        #expect(Set(intentParameters).count == intentParameters.count)
        #expect(Set(intentParameters) == Set(ParameterMapping.Parameter.allCases))
    }

    @Test("El respaldo de monto sale de la MISMA variable de Wallet que el monto (ADR-0033)")
    func elRespaldoDeMontoSaleDeLaMismaVariable() throws {
        let numeric = try #require(mappings.first { $0.intentParameter == .amount })
        let backup = try #require(mappings.first { $0.intentParameter == .amountText })

        // La razón de existir del respaldo: Shortcuts pierde el monto al
        // convertirlo a `Double`, así que la misma variable se conecta
        // también a un campo de texto. Si algún día apuntaran a variables
        // distintas, el respaldo dejaría de respaldar nada.
        #expect(backup.walletParameter == numeric.walletParameter)
    }

    @Test("Ningún campo del intent se anuncia con la etiqueta de otro")
    func ningunCampoSeAnunciaConLaEtiquetaDeOtro() {
        // El usuario busca estas etiquetas en pantalla: dos campos distintos
        // con el mismo texto lo dejan sin saber cuál llenar.
        let labels = mappings.map(\.intentLabel)
        #expect(Set(labels).count == labels.count)
        #expect(labels.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    @Test("Los campos de respaldo de ADR-0033 están presentes")
    func losCamposDeRespaldoEstanPresentes() {
        // El bug que motivó esto: la guía enseñaba a conectar solo tres
        // campos, y sin los respaldos un monto vacío de Wallet no registra
        // nada. Este es el test que faltaba.
        let intentParameters = Set(mappings.map(\.intentParameter))
        #expect(intentParameters.contains(.amountText))
        #expect(intentParameters.contains(.fullTransaction))
    }
}

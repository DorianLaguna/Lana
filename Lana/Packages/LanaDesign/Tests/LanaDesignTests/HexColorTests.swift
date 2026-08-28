import SwiftUI
import Testing
@testable import LanaDesign

@Suite("Color(hex:)")
struct HexColorTests {
    @Test("Un hex válido, con o sin #, construye un color")
    func hexValidoConstruyeUnColor() {
        #expect(Color(hex: "#1B4FD8") != nil)
        #expect(Color(hex: "1B4FD8") != nil)
    }

    @Test("Un hex mal formado devuelve nil, nunca truena")
    func hexMalFormadoDevuelveNil() {
        #expect(Color(hex: "no es un color") == nil)
        #expect(Color(hex: "#ABC") == nil)
        #expect(Color(hex: "") == nil)
    }

    @Test("La paleta de tarjetas son todos hex válidos")
    func laPaletaDeTarjetasSonTodosHexValidos() {
        for hex in LanaCardColors.palette {
            #expect(Color(hex: hex) != nil)
        }
    }
}

import Testing
@testable import LanaDesign

@Suite("RGBColor")
struct RGBColorTests {
    @Test("Blanco sobre negro da el contraste máximo, 21:1")
    func blancoSobreNegroDaContrasteMaximo() {
        let white = RGBColor(hex: "#FFFFFF")
        let black = RGBColor(hex: "#000000")
        #expect(abs(white.contrastRatio(with: black) - 21) < 0.01)
    }

    @Test("Un color consigo mismo da contraste 1:1")
    func colorConsigoMismoDaContrasteUno() {
        let color = RGBColor(hex: "#1B4FD8")
        #expect(abs(color.contrastRatio(with: color) - 1) < 0.01)
    }
}

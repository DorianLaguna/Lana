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

    @Test(
        "hsl(hue:saturation:lightness:) recupera el mismo tono al convertir de vuelta",
        arguments: [0.0, 45.0, 90.0, 180.0, 270.0, 315.0])
    func hslRecuperaElMismoTono(hue: Double) {
        let color = RGBColor.hsl(hue: hue, saturation: 0.6, lightness: 0.5)
        #expect(abs(color.hslHue - hue) < 0.5)
    }

    @Test("Saturación 0 da gris — mismo hue sin importar la lightness")
    func saturacionCeroDaGris() {
        let color = RGBColor.hsl(hue: 200, saturation: 0, lightness: 0.5)
        #expect(color.red == color.green)
        #expect(color.green == color.blue)
    }
}

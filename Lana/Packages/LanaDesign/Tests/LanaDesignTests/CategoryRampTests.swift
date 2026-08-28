import Testing
@testable import LanaDesign

/// La rampa de categorías se deriva rotando el tono del primario en pasos
/// fijos de 30° (360° / 12) — esta suite prueba esa construcción, la misma
/// que usa `LanaColors.categoryRamp` (ADR-0006: "tonos distinguibles").
/// Eran 8 tonos a 45°, ampliados a 12 a 30° cuando `SuggestedCategory`
/// llegó a 11 casos — con menos tonos que categorías, dos categorías
/// terminaban compartiendo color sin forma de distinguirlas en una gráfica.
@Suite("Rampa de categorías — ADR-0006")
struct CategoryRampTests {
    private func ramp(baseHue: Double, saturation: Double = 0.55, lightness: Double = 0.5) -> [RGBColor] {
        (0 ..< 12).map { step in
            RGBColor.hsl(hue: baseHue + Double(step) * 30, saturation: saturation, lightness: lightness)
        }
    }

    @Test("La rampa tiene 12 tonos")
    func rampaTieneDoceTonos() {
        #expect(ramp(baseHue: 0).count == 12)
    }

    @Test("Los 12 tonos están separados por 30° entre consecutivos", arguments: LanaTheme.allCases)
    func tonosSeparadosPor30Grados(theme: LanaTheme) {
        let hues = ramp(baseHue: theme.accentHue).map(\.hslHue)
        for index in 0 ..< hues.count {
            let next = hues[(index + 1) % hues.count]
            let current = hues[index]
            let delta = (next - current).truncatingRemainder(dividingBy: 360)
            let normalizedDelta = delta < 0 ? delta + 360 : delta
            #expect(abs(normalizedDelta - 30) < 0.5, "salto \(index)→\(index + 1): \(normalizedDelta)°")
        }
    }

    @Test("Ningún par de tonos en la rampa es indistinguible", arguments: LanaTheme.allCases)
    func ningunParEsIndistinguible(theme: LanaTheme) {
        let hues = ramp(baseHue: theme.accentHue).map(\.hslHue)
        for firstIndex in 0 ..< hues.count {
            for secondIndex in (firstIndex + 1) ..< hues.count {
                let raw = abs(hues[firstIndex] - hues[secondIndex])
                let circularDistance = min(raw, 360 - raw)
                // El paso mínimo entre dos tonos de la rampa es 30°; ningún
                // par debería quedar por debajo de eso.
                #expect(circularDistance >= 29.5, "tonos \(firstIndex) y \(secondIndex) a \(circularDistance)°")
            }
        }
    }
}

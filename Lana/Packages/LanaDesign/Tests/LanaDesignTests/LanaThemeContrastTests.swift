import Testing
@testable import LanaDesign

/// Verifica el contraste de la paleta del rediseño (ADR-0044): el acento de
/// cada tema como texto, lo que va encima de su relleno, la tinta con
/// opacidad y los semánticos fijos — en oscuro para todos los temas, y en
/// claro para los que siguen al sistema. "Un tema que no pasa no entra."
@Suite("Contraste de temas — ADR-0044")
struct LanaThemeContrastTests {
    static let textMinimum = 4.5

    private static func surfaces(_ neutrals: NeutralPalette) -> [(String, RGBColor)] {
        [("bg", neutrals.bg), ("surface", neutrals.surface), ("surface2", neutrals.surface2)]
    }

    /// Los modos en que un tema realmente se ve.
    private static func modes(for theme: LanaTheme) -> [NeutralPalette] {
        theme.forcesDarkAppearance ? [.dark] : [.dark, .light]
    }

    @Test("El acento de texto cumple 4.5:1 contra las superficies de cada modo", arguments: LanaTheme.allCases)
    func acentoComoTexto(theme: LanaTheme) {
        for neutrals in Self.modes(for: theme) {
            let accent = neutrals.isDark ? theme.palette.textDark : theme.palette.textLight
            for (name, surface) in Self.surfaces(neutrals) {
                let ratio = accent.contrastRatio(with: surface)
                #expect(ratio >= Self.textMinimum, "\(theme.displayName) acento / \(name): \(ratio)")
            }
        }
    }

    @Test("Lo que va sobre el relleno del acento da al menos 3:1", arguments: LanaTheme.allCases)
    func textoSobreRelleno(theme: LanaTheme) {
        let fill = theme.palette.fill
        let ratio = fill.preferredForeground.contrastRatio(with: fill)
        #expect(ratio >= 3, "\(theme.displayName) sobre relleno: \(ratio)")
    }

    @Test("ink cumple 4.5:1 contra las superficies de ambos modos", arguments: [NeutralPalette.dark, .light])
    func tintaPrincipal(neutrals: NeutralPalette) {
        for (name, surface) in Self.surfaces(neutrals) {
            let ratio = neutrals.ink.contrastRatio(with: surface)
            #expect(ratio >= Self.textMinimum, "ink / \(name): \(ratio)")
        }
    }

    @Test("Cada nivel de tinta cumple su mínimo ya mezclado sobre la superficie", arguments: InkLevel.allCases)
    func nivelesDeTinta(level: InkLevel) {
        guard let minimum = level.minimumContrast else { return }
        for neutrals in [NeutralPalette.dark, .light] {
            for (name, surface) in Self.surfaces(neutrals) {
                let blended = neutrals.inkBase.composited(alpha: neutrals.opacity(for: level), over: surface)
                let ratio = blended.contrastRatio(with: surface)
                #expect(ratio >= minimum, "\(level) \(neutrals.isDark ? "oscuro" : "claro") / \(name): \(ratio)")
            }
        }
    }

    private struct SemanticCase {
        let label: String
        let color: RGBColor
        let neutrals: NeutralPalette
    }

    @Test("attention y positive cumplen 4.5:1 en ambos modos")
    func semanticos() {
        let cases = [
            SemanticCase(label: "attention oscuro", color: LanaColors.attentionDark, neutrals: .dark),
            SemanticCase(label: "attention claro", color: LanaColors.attentionLight, neutrals: .light),
            SemanticCase(label: "positive oscuro", color: LanaColors.positiveDark, neutrals: .dark),
            SemanticCase(label: "positive claro", color: LanaColors.positiveLight, neutrals: .light)
        ]
        for testCase in cases {
            for (name, surface) in Self.surfaces(testCase.neutrals) {
                let ratio = testCase.color.contrastRatio(with: surface)
                #expect(ratio >= Self.textMinimum, "\(testCase.label) / \(name): \(ratio)")
            }
        }
    }

    @Test("Solo Obsidiana, Ámbar y Zafiro fuerzan oscuro")
    func temasSiempreOscuros() {
        let forced = LanaTheme.allCases.filter(\.forcesDarkAppearance)
        #expect(forced == [.obsidiana, .ambar, .zafiro])
    }
}

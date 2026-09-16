import Testing
@testable import LanaDesign

/// Verifica el contraste de la paleta del rediseño (ADR-0044): el acento de
/// cada tema como texto, lo que va encima de su relleno, la tinta con
/// opacidad y los semánticos fijos — en oscuro para todos los temas, y en
/// claro para los que siguen al sistema. "Un tema que no pasa no entra."
@Suite("Contraste de temas — ADR-0044")
struct LanaThemeContrastTests {
    static let textMinimum = 4.5
    /// Cuánto tiene que separarse un fondo teñido de la superficie que tiene
    /// abajo para verse sin leer el texto. No es un criterio WCAG: es el piso
    /// que atrapa un tinte que no pinta (Obsidiana daba 1.01).
    static let tintSeparation = 1.05

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

    /// La etiqueta de pestaña es de 10.5 pt: sin excepción de texto grande,
    /// así que las dos pestañas —activa e inactiva— piden 4.5:1 contra la
    /// barra ya compuesta, no contra `bg` pelón.
    @Test("Las pestañas cumplen 4.5:1 contra la barra compuesta sobre bg", arguments: LanaTheme.allCases)
    func etiquetasDePestana(theme: LanaTheme) {
        for neutrals in Self.modes(for: theme) {
            let bar = neutrals.composedTabBar
            let mode = neutrals.isDark ? "oscuro" : "claro"
            let inactive = neutrals.inkBase.composited(
                alpha: neutrals.opacity(for: NeutralPalette.tabBarInactiveInk),
                over: bar)
            let inactiveRatio = inactive.contrastRatio(with: bar)
            #expect(inactiveRatio >= Self.textMinimum, "\(theme.displayName) \(mode) inactiva: \(inactiveRatio)")

            let accent = neutrals.isDark ? theme.palette.textDark : theme.palette.textLight
            let activeRatio = accent.contrastRatio(with: bar)
            #expect(activeRatio >= Self.textMinimum, "\(theme.displayName) \(mode) activa: \(activeRatio)")
        }
    }

    /// Lo que va encima de un fondo de `attention`: el texto en `attention` del
    /// chip de duda y la tinta de apoyo de las tarjetas (`ink60` o más).
    @Test("El texto sobre los fondos de attention cumple 4.5:1", arguments: [NeutralPalette.dark, .light])
    func textoSobreFondosDeAttention(neutrals: NeutralPalette) {
        let attention = neutrals.isDark ? LanaColors.attentionDark : LanaColors.attentionLight
        let tints = neutrals.isDark ? AttentionTints.dark : AttentionTints.light
        let mode = neutrals.isDark ? "oscuro" : "claro"
        for (name, surface) in Self.surfaces(neutrals) {
            for (tintName, alpha) in [("soft", tints.soft), ("chip", tints.chip), ("softer", tints.softer)] {
                let tinted = attention.composited(alpha: alpha, over: surface)
                let attentionRatio = attention.contrastRatio(with: tinted)
                #expect(
                    attentionRatio >= Self.textMinimum,
                    "\(mode) attention / \(tintName) / \(name): \(attentionRatio)")

                let ink60 = neutrals.inkBase.composited(alpha: neutrals.opacity(for: .ink60), over: tinted)
                let inkRatio = ink60.contrastRatio(with: tinted)
                #expect(inkRatio >= Self.textMinimum, "\(mode) ink60 / \(tintName) / \(name): \(inkRatio)")
            }
        }
    }

    @Test("Los fondos teñidos se distinguen de la superficie", arguments: LanaTheme.allCases)
    func fondosTenidosSeDistinguen(theme: LanaTheme) {
        for neutrals in Self.modes(for: theme) {
            let mode = neutrals.isDark ? "oscuro" : "claro"
            let attention = neutrals.isDark ? LanaColors.attentionDark : LanaColors.attentionLight
            let attentionTints = neutrals.isDark ? AttentionTints.dark : AttentionTints.light
            let accent = neutrals.isDark ? theme.palette.textDark : theme.palette.textLight
            let accentTints = neutrals.isDark ? AccentTints.dark : AccentTints.light
            let tints = [
                ("attentionSoft", attention, attentionTints.soft),
                ("attentionSofter", attention, attentionTints.softer),
                ("accentSoft", accent, accentTints.soft),
                ("accentSofter", accent, accentTints.softer),
                ("accentHighlight", accent, accentTints.highlight)
            ]
            for (tintName, color, alpha) in tints {
                for (name, surface) in Self.surfaces(neutrals) {
                    let ratio = color.composited(alpha: alpha, over: surface).contrastRatio(with: surface)
                    #expect(
                        ratio >= Self.tintSeparation,
                        "\(theme.displayName) \(mode) \(tintName) / \(name): \(ratio)")
                }
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

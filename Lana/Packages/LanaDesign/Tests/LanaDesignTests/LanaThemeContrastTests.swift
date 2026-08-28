import Testing
@testable import LanaDesign

/// Verifica el requisito de ADR-0006 (ampliado por ADR-0016): los seis
/// temas cumplen 4.5:1 contra su **propia** superficie, en claro y oscuro
/// — ya no contra dos superficies globales compartidas, porque Obsidiana
/// tiene la suya, casi negra en sus dos variantes. "Un par que no pasa no
/// entra" — esta suite es justamente el filtro. Corre en `swift test`, sin
/// necesitar un contexto de renderizado (Docs/.claude/skills/theming).
@Suite("Contraste de temas — ADR-0006 / ADR-0016")
struct LanaThemeContrastTests {
    static let minimumRatio = 4.5

    private struct ContrastCase {
        let label: String
        let foreground: RGBColor
        let background: RGBColor
    }

    @Test(
        "El primario de cada tema cumple 4.5:1 contra la superficie propia, en claro y oscuro",
        arguments: LanaTheme.allCases)
    func primarioCumpleContraste(theme: LanaTheme) {
        let palette = theme.palette
        let lightRatio = palette.primaryLight.contrastRatio(with: palette.surfaceLight)
        let darkRatio = palette.primaryDark.contrastRatio(with: palette.surfaceDark)

        #expect(lightRatio >= Self.minimumRatio, "\(theme.displayName) primario claro: \(lightRatio)")
        #expect(darkRatio >= Self.minimumRatio, "\(theme.displayName) primario oscuro: \(darkRatio)")
    }

    @Test(
        "El secundario de cada tema cumple 4.5:1 contra la superficie propia, en claro y oscuro",
        arguments: LanaTheme.allCases)
    func secundarioCumpleContraste(theme: LanaTheme) {
        let palette = theme.palette
        let lightRatio = palette.secondaryLight.contrastRatio(with: palette.surfaceLight)
        let darkRatio = palette.secondaryDark.contrastRatio(with: palette.surfaceDark)

        #expect(lightRatio >= Self.minimumRatio, "\(theme.displayName) secundario claro: \(lightRatio)")
        #expect(darkRatio >= Self.minimumRatio, "\(theme.displayName) secundario oscuro: \(darkRatio)")
    }

    @Test(
        "textPrimary y textSecondary cumplen 4.5:1 contra superficie y superficie elevada propias, en claro y oscuro",
        arguments: LanaTheme.allCases)
    func textoCumpleContraste(theme: LanaTheme) {
        let palette = theme.palette
        let cases: [ContrastCase] = [
            ContrastCase(
                label: "textPrimary claro / surface",
                foreground: palette.textPrimaryLight,
                background: palette.surfaceLight),
            ContrastCase(
                label: "textPrimary claro / surfaceRaised",
                foreground: palette.textPrimaryLight,
                background: palette.surfaceRaisedLight),
            ContrastCase(
                label: "textPrimary oscuro / surface",
                foreground: palette.textPrimaryDark,
                background: palette.surfaceDark),
            ContrastCase(
                label: "textPrimary oscuro / surfaceRaised",
                foreground: palette.textPrimaryDark,
                background: palette.surfaceRaisedDark),
            ContrastCase(
                label: "textSecondary claro / surface",
                foreground: palette.textSecondaryLight,
                background: palette.surfaceLight),
            ContrastCase(
                label: "textSecondary claro / surfaceRaised",
                foreground: palette.textSecondaryLight,
                background: palette.surfaceRaisedLight),
            ContrastCase(
                label: "textSecondary oscuro / surface",
                foreground: palette.textSecondaryDark,
                background: palette.surfaceDark),
            ContrastCase(
                label: "textSecondary oscuro / surfaceRaised",
                foreground: palette.textSecondaryDark,
                background: palette.surfaceRaisedDark)
        ]
        for testCase in cases {
            let ratio = testCase.foreground.contrastRatio(with: testCase.background)
            #expect(ratio >= Self.minimumRatio, "\(theme.displayName) \(testCase.label): \(ratio)")
        }
    }

    /// Los 3 semánticos fijos (`positive`/`warning`/`critical`) no cambian
    /// con el tema (ADR-0006), pero ahora cada tema tiene su propia
    /// superficie — un rojo/verde/ámbar que pasaba contra blanco/negro puro
    /// puede no pasar contra el negro específico de un tema forzado a oscuro.
    ///
    /// Los temas con `forcesDarkAppearance` (Obsidiana, Ámbar, Zafiro) son
    /// un caso aparte: `ContentView` fuerza `.preferredColorScheme(.dark)`
    /// mientras alguno de ellos esté activo (ver ADR-0016/ADR-0017), así
    /// que la variante "clara" de estos semánticos — diseñada para verse
    /// sobre blanco — nunca llega a combinarse en la app real con su
    /// superficie casi negra. Probar esa combinación sería probar un estado
    /// que no existe; solo se verifica la variante oscura, que sí es la que
    /// de verdad se usa.
    @Test("Los semánticos fijos cumplen 4.5:1 contra la superficie propia de cada tema", arguments: LanaTheme.allCases)
    func semanticosFijosCumplenContraste(theme: LanaTheme) {
        let palette = theme.palette
        var cases: [ContrastCase] = [
            ContrastCase(
                label: "positive oscuro",
                foreground: LanaColors.positiveDark,
                background: palette.surfaceDark),
            ContrastCase(label: "warning oscuro", foreground: LanaColors.warningDark, background: palette.surfaceDark),
            ContrastCase(label: "critical oscuro", foreground: LanaColors.criticalDark, background: palette.surfaceDark)
        ]
        if !theme.forcesDarkAppearance {
            cases += [
                ContrastCase(
                    label: "positive claro",
                    foreground: LanaColors.positiveLight,
                    background: palette.surfaceLight),
                ContrastCase(
                    label: "warning claro",
                    foreground: LanaColors.warningLight,
                    background: palette.surfaceLight),
                ContrastCase(
                    label: "critical claro",
                    foreground: LanaColors.criticalLight,
                    background: palette.surfaceLight)
            ]
        }
        for testCase in cases {
            let ratio = testCase.foreground.contrastRatio(with: testCase.background)
            #expect(ratio >= Self.minimumRatio, "\(theme.displayName) \(testCase.label): \(ratio)")
        }
    }
}

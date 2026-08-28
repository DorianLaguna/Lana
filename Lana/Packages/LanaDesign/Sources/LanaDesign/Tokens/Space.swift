import Foundation

/// La única escala de espaciado válida en toda la app — unidad base 4pt
/// (Docs/.claude/skills/theming). Un `.padding(17)` en cualquier vista es un
/// bug: si el valor que necesitas no está aquí, la pregunta es qué caso de
/// `Space` le falta al sistema, no qué número poner.
public enum Space: CGFloat, Sendable, CaseIterable {
    case xs = 4
    case sm = 8
    case md = 16
    case lg = 24
    case xl = 32
    case xxl = 48
}

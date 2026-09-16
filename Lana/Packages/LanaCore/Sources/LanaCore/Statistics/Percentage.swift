import Foundation

/// Porcentajes enteros para mostrar, calculados sin pasar por `Double`.
public enum Percentage {
    /// El porcentaje entero de `part` sobre `whole`, redondeado al más cercano.
    /// `0` si `whole` es cero.
    ///
    /// Redondea **antes** de convertir a `Int`, y eso es lo que importa:
    /// `NSDecimalNumber.intValue` devuelve `0` para un `Decimal` con muchos
    /// dígitos fraccionarios —cualquier división que no termina, como
    /// 10,719.59 / 17,000—, así que un porcentaje convertido directo salía en
    /// 0 % casi siempre.
    public static func rounded(_ part: Decimal, of whole: Decimal) -> Int {
        guard whole != 0 else { return 0 }
        var value = part / whole * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}

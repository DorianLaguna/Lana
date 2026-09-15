import Foundation
import LanaCore
import LanaDesign

/// Cómo se escriben los montos en Hoy y Mes — siempre con el formato de
/// es_MX, igual que las fechas (`LanaDateFormat`), para que un iPhone en
/// inglés no mezcle "9,437.13" con "Septiembre".
enum MoneyDisplay {
    /// La cifra héroe partida en tres piezas de tamaños distintos.
    struct HeroParts: Equatable {
        /// "$", o "−$" si es negativo.
        let symbol: String
        /// "2,562".
        let integer: String
        /// ".87".
        let fraction: String
    }

    /// "$9,437.13".
    static func full(_ money: Money) -> String {
        money.amount.formatted(.currency(code: money.currency.rawValue).locale(LanaDateFormat.locale))
    }

    /// "$9,437": redondeado, sin centavos.
    static func whole(_ money: Money) -> String {
        money.amount.formatted(
            .currency(code: money.currency.rawValue)
                .locale(LanaDateFormat.locale)
                .precision(.fractionLength(0)))
    }

    /// "$12,000" si no tiene centavos; "$9,437.13" si los tiene.
    static func compact(_ money: Money) -> String {
        var amount = money.amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 0, .plain)
        return rounded == money.amount ? whole(money) : full(money)
    }

    static func heroParts(_ money: Money) -> HeroParts {
        var absolute = abs(money.amount)
        var integerPart = Decimal()
        NSDecimalRound(&integerPart, &absolute, 0, .down)
        var cents = (abs(money.amount) - integerPart) * 100
        var roundedCents = Decimal()
        NSDecimalRound(&roundedCents, &cents, 0, .plain)
        let centsValue = min(NSDecimalNumber(decimal: roundedCents).intValue, 99)
        let zero = Decimal(0).formatted(
            .currency(code: money.currency.rawValue)
                .locale(LanaDateFormat.locale)
                .precision(.fractionLength(0)))
        let symbol = zero.filter { !$0.isNumber && !$0.isWhitespace }
        return HeroParts(
            symbol: (money.amount < 0 ? "−" : "") + symbol,
            integer: integerPart.formatted(.number.grouping(.automatic).locale(LanaDateFormat.locale)),
            fraction: "." + (centsValue < 10 ? "0\(centsValue)" : "\(centsValue)"))
    }
}

import Foundation

/// Lo gastado y lo ingresado en un periodo, separado por moneda — nunca se
/// suman montos de monedas distintas (Docs/CONVENTIONS.md → Multi-moneda).
///
/// Nació como `MonthTotal` dentro de `DashboardFeature`. Vive aquí porque la
/// vista anual lo necesita con la misma forma y las features no pueden
/// importarse entre sí (Docs/ARCHITECTURE.md) — mismo motivo por el que
/// `DaySection` y `CategoryTotal` ya estaban en `LanaCore`. El nombre dejó de
/// decir "mes" porque el periodo ahora puede ser un mes o un año.
public struct PeriodTotal: Identifiable, Sendable, Hashable {
    public var id: Currency {
        currency
    }

    public let currency: Currency
    public let expenses: Decimal
    public let income: Decimal

    public init(currency: Currency, expenses: Decimal, income: Decimal) {
        self.currency = currency
        self.expenses = expenses
        self.income = income
    }

    /// Lo que quedó del ingreso después de gastar. Puede ser negativo — se
    /// gastó más de lo que entró, que es un dato, no un error.
    public var remaining: Decimal {
        income - expenses
    }
}

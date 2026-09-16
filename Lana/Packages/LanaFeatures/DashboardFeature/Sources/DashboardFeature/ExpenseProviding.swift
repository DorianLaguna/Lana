import Foundation
import LanaCore

/// De dónde saca un drill-down los gastos que muestra.
///
/// Existe porque `CategoryDetailModel` y `PaymentMethodDetailModel` sirven
/// igual para el mes (`DashboardModel`) que para el año (`YearModel`): lo
/// único que cambia es de qué modelo derivan. Sin esto habría que duplicar los
/// dos drill-downs y sus vistas, o darle al año una copia propia de los gastos
/// — justo la segunda copia que el comment de `CategoryDetailModel` explica
/// por qué no debe existir.
///
/// `internal` a propósito: todo lo que construye un drill-down vive en este
/// mismo target, y quien está afuera llega por las factorías
/// (`makeCategoryDetailModel(for:)`), nunca al inicializador.
@MainActor
protocol ExpenseProviding: AnyObject {
    /// Los gastos e ingresos del periodo que se está viendo, en vivo.
    var expenses: [Expense] { get }
    /// Qué participante es "yo" en cada lista compartida (ADR-0022), para
    /// contar solo la parte propia de un gasto compartido.
    var viewerIdentities: [SharedListID: ParticipantID] { get }
    /// El calendario del modelo, para agrupar por día sin depender del de la
    /// máquina.
    var calendar: Calendar { get }
    /// Las tarjetas guardadas, para que la fila diga "Crédito Nu" y no solo
    /// "Crédito" — y para distinguir una tarjeta borrada.
    var cards: [Card] { get }
    /// `false` si las tarjetas no se pudieron leer: sin esto, un fallo de
    /// lectura haría que todo movimiento con tarjeta dijera "Tarjeta eliminada".
    var hasLoadedCards: Bool { get }
    /// Cómo se nombra el periodo en un drill-down: "mes" o "año" ("Total en
    /// el mes", "35% de tu año").
    var periodNoun: String { get }
}

extension ExpenseProviding {
    /// Lo que se gastó en todo el periodo — la parte propia de cada gasto,
    /// igual que el total de un drill-down, para que su proporción cuadre.
    var personalExpenseTotal: Decimal {
        expenses
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.personalAmount(viewerIdentities: viewerIdentities).amount }
    }
}

/// La línea bajo la cifra de un drill-down: "11 gastos · 35% de tu mes".
/// Sin porcentaje cuando el periodo no tiene gastos.
///
/// Libre y no dentro de la vista: `swift test` truena al tocar miembros de
/// un tipo `View`.
func drillDownSummary(count: Int, share: Double, periodNoun: String) -> String {
    let movements = "\(count) " + (count == 1 ? "gasto" : "gastos")
    guard share > 0 else { return movements }
    return "\(movements) · \(Int((share * 100).rounded()))% de tu \(periodNoun)"
}

/// Qué fracción de `total` es `part`, en 0...1. Cero si el total no es positivo.
func fraction(_ part: Decimal, of total: Decimal) -> Double {
    guard total > 0 else { return 0 }
    return min(max(NSDecimalNumber(decimal: part / total).doubleValue, 0), 1)
}

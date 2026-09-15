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
}

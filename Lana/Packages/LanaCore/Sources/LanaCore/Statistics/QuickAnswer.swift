import Foundation

/// Las preguntas de un toque: cada una es **un cálculo determinista**, no una
/// consulta al modelo.
///
/// Existen porque tocar un chip fijo y esperar a que un modelo adivine cuál de
/// las seis herramientas corresponde es pagar espera —y depender de Apple
/// Intelligence— por un mapeo que ya está decidido desde que se escribió el
/// chip. La pregunta escrita a mano sí necesita el modelo: ahí hay lenguaje que
/// entender. Esto no.
///
/// El texto que devuelven es el mismo que ya consume el modelo por el otro
/// camino (`LedgerToolbox`): una sola fuente de verdad para cada cifra.
public enum QuickAnswer: String, Sendable, CaseIterable, Identifiable, Hashable {
    /// En qué se fue el dinero, por categoría.
    case enQueSeFue
    /// Contra el mes anterior.
    case contraElMesPasado
    /// Los movimientos más grandes.
    case gastosMasGrandes
    /// De dónde vino el dinero.
    case deDondeVino
    /// Cuánto se debe en cada tarjeta.
    case deudaDeTarjetas
    /// Cuánto queda del periodo de pago vigente.
    case cuantoQueda

    public var id: String {
        rawValue
    }

    /// Cómo se ofrece en pantalla.
    ///
    /// Sin "este mes" a propósito: la pantalla tiene un selector de periodo, y
    /// la respuesta sale sobre el que se esté viendo. Un chip que dice "este
    /// mes" mirando agosto miente.
    public var title: String {
        switch self {
        case .enQueSeFue: "¿En qué se me fue?"
        case .contraElMesPasado: "¿Gasté más que el mes pasado?"
        case .gastosMasGrandes: "¿Cuáles fueron mis gastos más grandes?"
        case .deDondeVino: "¿De dónde me vino el dinero?"
        case .deudaDeTarjetas: "¿Cuánto debo en mis tarjetas?"
        case .cuantoQueda: "¿Cuánto me queda de esta quincena?"
        }
    }

    /// `true` si esta pregunta se puede contestar sobre ese periodo.
    ///
    /// Cuatro de las seis se calculan sobre un mes concreto. Viendo el año, en
    /// vez de inventarles un mes —contestar sobre septiembre a quien está
    /// mirando 2026 sería peor que no ofrecer nada— simplemente no se ofrecen.
    public func supports(_ period: QueryPeriod) -> Bool {
        switch self {
        case .enQueSeFue, .contraElMesPasado, .gastosMasGrandes, .deDondeVino:
            period.month != nil
        case .deudaDeTarjetas, .cuantoQueda:
            // No dependen del periodo: son el estado de hoy.
            true
        }
    }

    /// Las que se pueden ofrecer sobre un periodo, en orden.
    public static func available(for period: QueryPeriod) -> [QuickAnswer] {
        allCases.filter { $0.supports(period) }
    }

    /// Corre el cálculo. Devuelve texto ya formateado, igual que el resto de
    /// `LedgerToolbox` — nunca un `Decimal` suelto.
    public func answer(
        using toolbox: LedgerToolbox,
        viewing period: QueryPeriod,
        asOf date: Date = Date(),
        calendar: Calendar = .current) async -> String {
        switch self {
        case .enQueSeFue:
            guard let month = period.month else { return Self.needsAMonth }
            return await toolbox.totalPorCategoria(year: period.year, month: month)
        case .contraElMesPasado:
            guard let month = period.month else { return Self.needsAMonth }
            let previous = Self.previousMonth(year: period.year, month: month, calendar: calendar)
            return await toolbox.comparaMeses(
                yearA: period.year, monthA: month,
                yearB: previous.year, monthB: previous.month)
        case .gastosMasGrandes:
            guard let month = period.month else { return Self.needsAMonth }
            return await toolbox.mayoresGastos(year: period.year, month: month)
        case .deDondeVino:
            guard let month = period.month else { return Self.needsAMonth }
            return await toolbox.origenDelIngreso(year: period.year, month: month)
        case .deudaDeTarjetas:
            return await toolbox.deudaPorTarjeta(asOf: date)
        case .cuantoQueda:
            return await toolbox.disponibleProyectado(asOf: date)
        }
    }

    /// El mes anterior, cruzando el año cuando toca. Enero de 2026 tiene detrás
    /// diciembre de 2025, no el mes cero.
    static func previousMonth(year: Int, month: Int, calendar: Calendar) -> (year: Int, month: Int) {
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let previous = calendar.date(byAdding: .month, value: -1, to: start)
        else {
            return month > 1 ? (year, month - 1) : (year - 1, 12)
        }
        return (calendar.component(.year, from: previous), calendar.component(.month, from: previous))
    }

    /// No debería verse: `supports(_:)` ya filtra antes de ofrecerla.
    private static let needsAMonth = "Esa pregunta se contesta sobre un mes. Elige un mes para verla."
}

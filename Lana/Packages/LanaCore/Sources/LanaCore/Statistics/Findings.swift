import Foundation

/// Algo que el usuario **no sabía**, sacado de su propio historial.
///
/// Existe porque el resumen narrado del Análisis no ayudaba: se le pedía al
/// modelo "hábitos que se notan en los datos" mientras se le entregaban solo
/// las sumas del mes en curso, sin comparación contra nada. Con esos insumos lo
/// único posible era reformular lo que ya se veía dos pantallas antes.
///
/// El texto se redacta aquí, no en la vista ni en el modelo del sistema: así se
/// prueba con igualdad exacta y se lee igual con o sin Apple Intelligence. Si
/// algún día el modelo lo reescribe más bonito, parte de esto — nunca lo
/// produce (Docs/CLAUDE.md: el modelo no calcula).
public struct Finding: Sendable, Hashable, Identifiable {
    /// De qué tipo es. Sirve para que la UI pueda darles icono o para filtrar,
    /// no para ordenarlos: eso lo decide `magnitude`.
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        /// Cómo vas contra el mismo día del mes pasado.
        case pace
        /// Cobros que se repiten solos y no están dados de alta como recurrentes.
        case repeatedCharges
        /// Una categoría que se salió de tu propio promedio.
        case categoryDeviation
        /// Cuánto más pesa un día de fin de semana.
        case weekend
        /// Lo chico que se repite y junto sí pesa.
        case antExpenses
    }

    public var id: String {
        "\(kind.rawValue)-\(headline)"
    }

    public let kind: Kind
    /// La frase principal, ya escrita ("Vas $1,200 arriba de como ibas el 15 de agosto").
    public let headline: String
    /// De dónde sale la cifra, cuando hace falta explicarla. Nunca repite el
    /// encabezado.
    public let detail: String?
    /// Cuánto dinero mueve el hallazgo. **No se muestra**: es solo el criterio
    /// para ordenar, porque lo que más mueve es lo que más puede cambiar una
    /// decisión.
    public let magnitude: Decimal
    public let currency: Currency

    public init(kind: Kind, headline: String, detail: String? = nil, magnitude: Decimal, currency: Currency) {
        self.kind = kind
        self.headline = headline
        self.detail = detail
        self.magnitude = magnitude
        self.currency = currency
    }
}

/// El motor: recibe el historial y devuelve lo que valga la pena decir.
///
/// Es puro y vive en `LanaCore` para poder probarse sin simulador y sin modelo.
/// No persiste nada (ADR-0005) ni cruza monedas (Docs/CONVENTIONS.md): se
/// resuelve una moneda a la vez.
public enum Findings {
    /// Lo que necesita el motor para trabajar.
    public struct Input: Sendable {
        /// Cualquier fecha del mes que se analiza.
        public let month: Date
        /// La moneda a resolver. Nunca se mezclan.
        public let currency: Currency
        /// El mes que se analiza **y los meses anteriores** que se quieran
        /// comparar. Sin historia previa, los hallazgos que comparan no salen:
        /// es correcto, no es una falla.
        public let expenses: [Expense]
        /// Qué participante es "yo" en cada lista compartida, para contar solo
        /// la parte propia de un gasto compartido (ADR-0022).
        public let viewerIdentities: [SharedListID: ParticipantID]
        /// Qué día es hoy. Decide hasta dónde se compara dentro del mes.
        public let asOf: Date

        public init(
            month: Date,
            currency: Currency,
            expenses: [Expense],
            viewerIdentities: [SharedListID: ParticipantID] = [:],
            asOf: Date = Date()) {
            self.month = month
            self.currency = currency
            self.expenses = expenses
            self.viewerIdentities = viewerIdentities
            self.asOf = asOf
        }
    }

    /// Cuántos meses hacia atrás se necesitan para que los hallazgos que
    /// comparan tengan con qué. Quien lea el store debe pedir al menos esto.
    public static let monthsOfHistoryNeeded = 3

    /// Los hallazgos del periodo, **de mayor a menor dinero movido**.
    ///
    /// - Parameter limit: cuántos devolver. Cuatro es lo que cabe sin que la
    ///   pantalla se vuelva una lista que nadie lee.
    public static func resolve(_ input: Input, calendar: Calendar = .current, limit: Int = 4) -> [Finding] {
        let context = FindingContext(input: input, calendar: calendar)
        let found = [
            context.pace(),
            context.repeatedCharges(),
            context.categoryDeviation(),
            context.weekendWeight(),
            context.antExpenses()
        ].compactMap(\.self)

        return Array(
            found
                .sorted { first, second in
                    first.magnitude == second.magnitude
                        ? first.kind.rawValue < second.kind.rawValue
                        : first.magnitude > second.magnitude
                }
                .prefix(limit))
    }
}

/// De dónde viene el dinero que entra. Lista cerrada, con subcategoría abierta
/// encima — misma forma que los gastos (ADR-0011), catálogo aparte.
///
/// Son ocho valores propios y no las once de `SuggestedCategory`: mezclarlas
/// daría un picker donde "comida" convive con "sueldo", que no significa nada.
/// Un ingreso nunca se etiqueta contra una categoría de gasto, y tampoco entra
/// a la mezcla 50/30/20 — ahí el ingreso es el denominador, no un tramo
/// (ADR-0037).
///
/// A diferencia de las de gasto, **no las asigna el parser**: se eligen a mano
/// en el `+` y en el editor (ADR-0040). Por eso no hay un `@Generable` espejo
/// en `LanaParsing`, y `Expense.category` de un ingreso capturado por voz sigue
/// llegando vacío hasta que alguien lo corrija.
public enum IncomeCategory: String, Sendable, Hashable, CaseIterable, Codable, Identifiable {
    /// Nómina, quincena, aguinaldo.
    case sueldo
    /// Honorarios, proyectos, comisiones.
    case freelance
    /// Vendiste algo tuyo.
    case venta
    /// Te rentan una propiedad.
    case renta
    /// Rendimientos, dividendos, intereses.
    case inversion
    /// Te devolvieron dinero.
    case reembolso
    /// Te dieron dinero.
    case regalo
    /// Lo que no cae en las de arriba.
    case otro

    public var id: String {
        rawValue
    }

    /// El raw value es ASCII a propósito (se guarda como texto libre en
    /// `Expense.category`) — esto es lo que sí lleva acento, para el picker.
    public var displayName: String {
        switch self {
        case .inversion: "Inversión"
        default: rawValue.capitalized
        }
    }

    /// Qué significa cada una, para el pie del picker — la misma ayuda que el
    /// parser le da al modelo para los gastos, aquí dirigida a la persona.
    public var hint: String {
        switch self {
        case .sueldo: "Nómina, quincena, aguinaldo"
        case .freelance: "Honorarios, proyectos, comisiones"
        case .venta: "Vendiste algo tuyo"
        case .renta: "Te rentan una propiedad"
        case .inversion: "Rendimientos, dividendos, intereses"
        case .reembolso: "Te devolvieron dinero"
        case .regalo: "Te dieron dinero"
        case .otro: "Lo que no cae en las de arriba"
        }
    }

    /// Un índice fijo y único **dentro de este catálogo**, para que dos
    /// categorías de ingreso nunca compartan tono en la misma gráfica — la
    /// misma garantía que `SuggestedCategory.rampIndex` da para los gastos.
    ///
    /// Entre catálogos sí puede haber choques y no se pueden evitar: once
    /// categorías de gasto más ocho de ingreso son diecinueve, y la rampa tiene
    /// doce tonos. No estorba, porque gastos e ingresos se desglosan en bloques
    /// separados y nunca en la misma barra. El desfase existe para que al menos
    /// las dos más frecuentes —"comida" y "sueldo"— no salgan iguales.
    public var rampIndex: Int {
        // swiftlint:disable:next force_unwrapping
        let position = Self.allCases.firstIndex(of: self)!
        return (SuggestedCategory.allCases.count + position) % 12
    }
}

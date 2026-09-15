import FoundationModels

/// El grupo de presupuesto, tal como lo devuelve el modelo.
///
/// Espejo de `LanaCore.BudgetGroup` — mismos raw values. `LanaCore` no puede
/// importar `FoundationModels`, así que el tipo se duplica igual que
/// `ExpenseCategory`/`SuggestedCategory` en el parser. Si esta lista cambia,
/// la otra también.
@Generable
enum BudgetGroupLabel: String, Sendable, CaseIterable, Codable {
    case necesidad
    case deseo
    case ahorro
}

extension BudgetGroupLabel {
    /// El `@Guide` no puede ir por-caso en un enum `@Generable` (solo en
    /// stored properties), así que la definición de cada grupo vive aquí y la
    /// referencia el campo `group`. Cero cifras: solo reglas abstractas
    /// (ADR-0013).
    static let guideDescription = """
    En qué grupo de presupuesto cae este tipo de gasto:
    - necesidad: lo que sostiene la vida diaria y no se puede dejar de pagar \
    sin consecuencias reales — vivienda, servicios básicos, comida de casa, \
    transporte para trabajar, salud, educación obligatoria, seguros, pagos \
    mínimos de deuda.
    - deseo: lo que mejora la vida pero se puede posponer sin consecuencias \
    — restaurantes, entretenimiento, suscripciones de ocio, ropa más allá de \
    lo indispensable, viajes, antojos, hobbies.
    - ahorro: dinero que sale de la cuenta pero sigue siendo del usuario o \
    reduce su deuda por encima del mínimo — transferencias a una cuenta de \
    ahorro, inversiones, aportaciones al retiro, abonos extra a un crédito.

    Cuando algo pueda caer en dos grupos, elige por el uso más común en \
    México, no por el caso extremo. La misma etiqueta se aplica a todos los \
    gastos de ese tipo, así que decide para el caso típico.
    """
}

/// Una etiqueta clasificada: el par categoría/subcategoría que se te dio, y el
/// grupo que le toca.
@Generable
struct ClassifiedLabel: Sendable {
    @Guide(description: "La etiqueta, copiada exactamente como venía en la lista.")
    var label: String

    @Guide(description: BudgetGroupLabel.guideDescription)
    var group: BudgetGroupLabel
}

/// El lote completo de etiquetas clasificadas.
@Generable
struct ClassifiedLabelBatch: Sendable {
    @Guide(description: """
    Una entrada por cada etiqueta de la lista que se te dio, en el mismo \
    orden y sin inventar etiquetas que no estén en ella.
    """)
    var labels: [ClassifiedLabel]
}

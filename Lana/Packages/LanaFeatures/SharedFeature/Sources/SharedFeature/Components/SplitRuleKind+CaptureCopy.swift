import LanaCore

/// La copia específica del formulario de captura de Compartido — el nombre
/// y el resto de `SplitRuleKind` viven en `LanaCore` porque tres módulos
/// distintos ofrecen ese picker (ADR-0030); esto es solo lo que necesita
/// **este** formulario, que es el único que captura números por
/// participante.
extension SplitRuleKind {
    /// Una línea corta debajo del picker — con 5 opciones y nombres
    /// parecidos ("Proporcional" vs "Porcentaje"), el nombre solo no
    /// alcanza para saber qué va a pasar antes de capturar nada.
    var helpText: String {
        switch self {
        case .equally: "Se divide en partes iguales entre todos."
        case .payerOnly: "Solo paga quien lo registró, nadie más debe nada."
        case .proportional: """
            Escribe cualquier número que represente el peso de cada quien — su ingreso, por ejemplo. \
            No hace falta que sumen nada en particular: Lana calcula la proporción sola.
            """
        case .percentage: "Le das un porcentaje a cada quien; deben sumar 100%."
        case .exactAmounts: "Escribes el monto exacto de cada quien; deben sumar el total."
        }
    }

    /// Placeholder del campo por participante — distinto por regla para
    /// que quede claro qué se espera ahí sin depender solo del `helpText`
    /// de arriba.
    var fieldPlaceholder: String {
        switch self {
        case .equally, .payerOnly: "0"
        case .proportional: "Ingreso o peso"
        case .percentage: "%"
        case .exactAmounts: "$"
        }
    }
}

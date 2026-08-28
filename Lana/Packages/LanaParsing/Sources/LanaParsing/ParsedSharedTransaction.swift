import FoundationModels

/// Como `ParsedTransaction`, pero dentro de una lista compartida: además de
/// qué se gastó, hace falta quién pagó y cómo se divide. `@Generable`
/// aparte porque activarlo solo dentro de listas compartidas evita pedirle
/// al modelo campos que no aplican a un gasto personal.
@Generable
public struct ParsedSharedTransaction: Sendable {
    @Guide(description: "Los datos del gasto o ingreso en sí, igual que en modo personal.")
    public var transaction: ParsedTransaction

    @Guide(description: "Quién pagó, tal como aparece en el texto — un nombre o 'yo'. Vacío si no se menciona.")
    public var payerHint: String

    @Guide(description: """
    Cómo se divide el gasto si el texto lo menciona: 'igual' (partes \
    iguales), 'yo' (solo quien pagó, sin dividir), o una proporción o \
    porcentaje descrito en el texto. Vacío si no se menciona — se usa la \
    regla vigente de la lista.
    """)
    public var splitHint: String
}

@Generable
public struct ParsedSharedTransactionBatch: Sendable {
    @Guide(description: """
    Los gastos o ingresos compartidos mencionados en el texto. Casi \
    siempre contiene exactamente un elemento y termina ahí.
    """)
    public var transactions: [ParsedSharedTransaction]
}

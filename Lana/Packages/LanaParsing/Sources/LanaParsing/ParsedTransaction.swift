import FoundationModels

/// Lo que el modelo extrae de una frase en lenguaje natural, antes de
/// cualquier validación determinista (`AmountValidator`, filtro de monto
/// ≤ 0). `amount` y `category` son lo único que se compara contra el golden
/// set — el resto es orientativo.
@Generable
public struct ParsedTransaction: Sendable {
    @Guide(description: """
    true si es un ingreso (dinero que entra); false si es un gasto \
    (dinero que sale). La mayoría de las frases describen gastos.
    """)
    public var isIncome: Bool

    @Guide(description: "Monto numérico, sin símbolo de moneda ni separador de miles.")
    public var amount: Double

    @Guide(description: """
    Código de moneda ISO 4217 de 3 letras, en mayúsculas, si el texto la \
    menciona explícitamente (dólares, euros...). Si no se menciona \
    moneda, usa MXN.
    """)
    public var currencyCode: String

    @Guide(description: """
    Qué se compró, cobró o pagó, en 2 a 5 palabras, en español. Si la \
    persona lo dijo de forma torpe, cortada o con muletillas pero el \
    significado es claro, escribe el concepto limpio y bien dicho — no \
    copies literalmente cada palabra tal cual se dijo, se trata de \
    comunicar qué fue, no de transcribir.
    """)
    public var concept: String

    @Guide(description: ExpenseCategory.guideDescription)
    public var category: ExpenseCategory

    @Guide(description: """
    Un nombre corto y genérico para agrupar gastos parecidos dentro de la \
    categoría, en 1 a 3 palabras — el tipo de cosa que fue, no la marca ni \
    el nombre exacto del producto (p. ej. "dulces" o "botana", no el \
    nombre de una marca específica; "gasolina", "café", "mantenimiento", \
    "streaming" son del mismo estilo). Es obligatorio proponer algo \
    siempre que el texto nombre un producto o servicio identificable, \
    incluso si nunca se ha visto antes y aunque el texto sea muy corto — \
    generaliza a qué tipo de cosa pertenece en vez de dejarlo vacío. Si \
    las instrucciones traen una lista de subcategorías que esta persona \
    ya usa en esa categoría y alguna corresponde claramente a lo que \
    describe el texto, usa ese nombre tal cual — no inventes una variante \
    nueva cuando ya existe una que aplica. Vacío únicamente cuando el \
    texto es demasiado genérico para identificar ningún tipo de cosa \
    (p. ej. solo dice cuánto costó, sin decir qué fue) — nunca 'otro' ni \
    variantes como subcategoría.
    """)
    public var subcategory: String

    @Guide(description: """
    Cómo se pagó, si el texto lo menciona: efectivo, débito, crédito o \
    transferencia. Vacío si no se menciona.
    """)
    public var paymentMethodHint: String

    @Guide(description: """
    El alias de la tarjeta si el texto lo menciona (p. ej. 'la Nu', 'la \
    azul'). Vacío si no se menciona ninguna tarjeta.
    """)
    public var cardHint: String

    @Guide(description: "true si algo quedó ambiguo o dudoso y conviene que la persona lo revise antes de confirmar.")
    public var needsReview: Bool
}

/// El objetivo de generación real: casi siempre una frase describe una sola
/// transacción, pero puede describir varias ("compré esto y también aquello").
@Generable
public struct ParsedTransactionBatch: Sendable {
    @Guide(description: """
    Los gastos o ingresos mencionados en el texto. La lista casi siempre \
    contiene exactamente un elemento y termina ahí — solo agrega más de \
    uno si el texto describe con claridad varias compras o cobros distintos. \
    Vacía si el texto no describe ninguna transacción real — nunca inventes \
    una para llenar la lista.
    """)
    public var transactions: [ParsedTransaction]
}

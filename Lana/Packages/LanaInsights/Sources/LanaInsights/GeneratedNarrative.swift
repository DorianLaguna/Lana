import FoundationModels

/// Lo que el modelo redacta sobre un periodo. Espejo de
/// `LanaCore.PeriodNarrative`, que no puede ser `@Generable` porque `LanaCore`
/// no importa `FoundationModels`.
@Generable
struct GeneratedNarrative: Sendable {
    @Guide(description: """
    Dos o tres frases sobre qué pasó con el dinero en el periodo, en segunda \
    persona y en español mexicano neutro. Usa únicamente las cifras que se te \
    dieron, copiadas tal cual. No sumes, no restes, no calcules porcentajes y \
    no compares cifras que no vengan ya comparadas.
    """)
    var summary: String

    @Guide(description: """
    Entre cero y tres hábitos que se noten en los datos, una frase cada uno. \
    Si los datos no muestran un patrón claro, devuelve la lista vacía en vez \
    de inventar uno.
    """)
    var patterns: [String]

    @Guide(description: """
    Entre cero y tres ideas de dónde se podría ajustar, una frase cada una. \
    Son opciones que el usuario puede tomar o no, nunca correcciones ni \
    regaños: nada de "deberías", "te excediste" ni "cuidado". Si no hay nada \
    útil que proponer, devuelve la lista vacía.
    """)
    var suggestions: [String]
}

/// La regla que el modelo propone, de una lista cerrada.
@Generable
struct GeneratedRuleRecommendation: Sendable {
    @Guide(description: """
    El identificador de una de las reglas que se te ofrecieron, copiado \
    exactamente. No inventes reglas ni propongas porcentajes propios.
    """)
    var ruleID: String

    @Guide(description: """
    Una sola frase que explique por qué esa regla le queda a este usuario, \
    en tono de sugerencia y no de corrección.
    """)
    var reason: String
}

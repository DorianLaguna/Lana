import Foundation

/// Los tres grupos en los que se reparte el dinero para medirlo contra una
/// regla de presupuesto.
///
/// Los nombres de los casos van en español, no en inglés, por la misma razón
/// que `SuggestedCategory`: son **vocabulario de salida del modelo**, y este
/// enum es el espejo en `LanaCore` del `@Generable` que vive en la
/// implementación concreta (`LanaCore` no puede importar `FoundationModels`).
/// Que los dos digan literalmente lo mismo es lo que evita una tabla de
/// traducción entre ambos.
public enum BudgetGroup: String, Sendable, Hashable, CaseIterable, Codable, Identifiable {
    case necesidad
    case deseo
    case ahorro

    public var id: String {
        rawValue
    }

    /// Cómo se le llama en pantalla.
    public var displayName: String {
        switch self {
        case .necesidad: "Necesidades"
        case .deseo: "Deseos"
        case .ahorro: "Ahorro"
        }
    }
}

/// Las reglas de presupuesto que Lana ofrece.
///
/// **Cuál seguir es decisión del usuario, no una constante del código.** El
/// 50/30/20 es la más conocida, no la única ni la correcta para todos: con un
/// ingreso justo, el 50% de necesidades es inalcanzable y la barra viviría
/// siempre en falta por una meta que nunca dio — exactamente el tono que el
/// proyecto prohíbe (Docs/CLAUDE.md → Tono). Lana recomienda; no impone.
///
/// Las cuatro se miden sobre el **ingreso** y usan los mismos tres grupos, así
/// que cambiar de regla solo cambia las metas: no reclasifica nada ni vuelve a
/// llamar al modelo. Eso es lo que hace barato dejarlo en manos del usuario.
public enum BudgetRule: String, Sendable, Hashable, CaseIterable, Codable, Identifiable {
    /// 50% necesidades, 30% deseos, 20% ahorro.
    case fiftyThirtyTwenty
    /// 70% necesidades, 20% deseos, 10% ahorro.
    case seventyTwentyTen
    /// 60% necesidades, 20% deseos, 20% ahorro.
    case sixtyTwentyTwenty
    /// 20% al ahorro; el 80% restante no se divide.
    case payYourselfFirst

    public var id: String {
        rawValue
    }

    /// Cómo se le llama en pantalla.
    public var displayName: String {
        switch self {
        case .fiftyThirtyTwenty: "50/30/20"
        case .seventyTwentyTen: "70/20/10"
        case .sixtyTwentyTwenty: "60/20/20"
        case .payYourselfFirst: "Págate primero"
        }
    }

    /// Una línea que explica para quién es, para el selector.
    public var summary: String {
        switch self {
        case .fiftyThirtyTwenty:
            "La más conocida: mitad para lo necesario, 30% para lo que quieras, 20% al ahorro."
        case .seventyTwentyTen:
            "Para cuando el ingreso está justo y la mitad no alcanza para lo necesario."
        case .sixtyTwentyTwenty:
            "Punto medio: afloja lo necesario sin bajar la meta de ahorro."
        case .payYourselfFirst:
            "La más simple: aparta 20% y el resto es tuyo, sin dividirlo."
        }
    }

    /// La meta del grupo como fracción del ingreso.
    ///
    /// `nil` significa que **esta regla no fija meta para ese grupo**, no que
    /// la meta sea cero: "Págate primero" solo compromete el ahorro y deja el
    /// resto sin repartir a propósito. La UI muestra esos grupos como dato,
    /// sin comparación.
    public func target(for group: BudgetGroup) -> Decimal? {
        targets[group]
    }

    /// Las metas de la regla. Un grupo ausente del diccionario es un grupo sin
    /// meta — por eso "Págate primero" solo trae una entrada.
    private var targets: [BudgetGroup: Decimal] {
        switch self {
        case .fiftyThirtyTwenty:
            [.necesidad: Self.percent(50), .deseo: Self.percent(30), .ahorro: Self.percent(20)]
        case .seventyTwentyTen:
            [.necesidad: Self.percent(70), .deseo: Self.percent(20), .ahorro: Self.percent(10)]
        case .sixtyTwentyTwenty:
            [.necesidad: Self.percent(60), .deseo: Self.percent(20), .ahorro: Self.percent(20)]
        case .payYourselfFirst:
            [.ahorro: Self.percent(20)]
        }
    }

    /// Un porcentaje entero como fracción exacta. Dividir enteros en `Decimal`
    /// evita el literal fraccionario, que pasaría por `Double` antes de llegar
    /// a `Decimal` (ver el doc comment de `Money`).
    private static func percent(_ value: Int) -> Decimal {
        Decimal(value) / 100
    }
}

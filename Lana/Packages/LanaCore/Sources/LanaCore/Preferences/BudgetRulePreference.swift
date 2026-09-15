import Foundation

/// Dónde se guarda la regla de presupuesto que eligió el usuario.
///
/// Vive en `LanaCore` —y no dentro de una feature— porque la lee y la escribe
/// `InsightsFeature`, y las features no pueden importarse entre sí. `UserDefaults`
/// es `Foundation`, así que esto no rompe la regla de que `LanaCore` solo
/// importa `Foundation` (Docs/ARCHITECTURE.md).
///
/// Es una **preferencia**, no un derivado: guardarla no contradice "los saldos
/// nunca se persisten" (ADR-0005). Se persiste al instante, sin botón de
/// guardar, igual que el tema en `SettingsModel`.
/// No es `Sendable` porque `UserDefaults` no lo es. No hace falta: la lee y la
/// escribe un modelo `@MainActor`, igual que el tema en `SettingsModel`.
public struct BudgetRulePreference {
    private let userDefaults: UserDefaults
    private static let ruleKey = "lana.budgetRule"
    private static let dismissedSuggestionKey = "lana.budgetRule.suggestionDismissed"

    /// - Parameter userDefaults: dónde se persiste. Inyectable para que los
    ///   tests no ensucien los defaults reales.
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// La regla elegida, o `nil` si el usuario todavía no elige ninguna.
    ///
    /// `nil` es un estado de primera clase, no un hueco a rellenar con un
    /// default: mientras no elija, la pantalla muestra su mezcla real sin
    /// meta. Ponerle una meta que no pidió es justo lo que esta app no hace.
    public var rule: BudgetRule? {
        guard let rawValue = userDefaults.string(forKey: Self.ruleKey) else { return nil }
        return BudgetRule(rawValue: rawValue)
    }

    /// Guarda la regla elegida. `nil` la quita y regresa a "sin regla".
    public func setRule(_ rule: BudgetRule?) {
        guard let rule else {
            userDefaults.removeObject(forKey: Self.ruleKey)
            return
        }
        userDefaults.set(rule.rawValue, forKey: Self.ruleKey)
    }

    /// Si el usuario ya descartó la regla que Lana le sugirió.
    ///
    /// Volver a proponer lo mismo cada vez que abre la pantalla es regañar con
    /// otro nombre, así que se pregunta una vez y se respeta la respuesta.
    public var hasDismissedSuggestion: Bool {
        userDefaults.bool(forKey: Self.dismissedSuggestionKey)
    }

    /// Recuerda que el usuario descartó la sugerencia.
    public func dismissSuggestion() {
        userDefaults.set(true, forKey: Self.dismissedSuggestionKey)
    }
}

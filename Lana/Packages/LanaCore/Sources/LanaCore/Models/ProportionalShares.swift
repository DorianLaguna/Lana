import Foundation

/// Convertir pesos crudos (ingresos, o lo que el usuario escriba en el
/// formulario) a las fracciones que `SplitRule.proportional` exige: que
/// sumen **exactamente** 1, porque se congelan tal cual en el evento
/// (ADR-0007) y `SplitRule.portions(of:)` rechaza cualquier otra cosa.
///
/// Vive en `LanaCore` y no en `SharedFeature` porque hay dos caminos que
/// producen un split proporcional para el mismo gasto — los ingresos ya
/// capturados de la lista (`SharedList.proportionalSplitFromIncomes`) y la
/// captura a mano en el formulario completo — y si cada uno normaliza por su
/// cuenta, los mismos números pueden congelar centavos distintos según por
/// dónde se haya entrado.
public enum ProportionalShares {
    /// Las fracciones normalizadas de `participants`, tomando el peso de
    /// cada quien de `weights` (lo que no esté ahí cuenta como 0 — un
    /// participante sin capturar no se excluye, pesa cero).
    ///
    /// El último participante **por orden de `ParticipantID`** se ajusta con
    /// la resta en vez de la división: así la suma cierra en 1 exacto sin
    /// arrastrar el residuo de redondeo de `Decimal`, y el desempate es
    /// determinista — no depende del orden del roster, que cambia según la
    /// pantalla desde la que se mire.
    ///
    /// Si los pesos suman 0 (nada capturado todavía) no hay proporción que
    /// derivar y se regresan tal cual, sin dividir entre cero: quien llama
    /// decide si eso es "todavía no" o un error que mostrar.
    public static func normalized(
        weights: [ParticipantID: Decimal],
        among participants: [ParticipantID]) -> [ParticipantID: Decimal] {
        let total = participants.reduce(Decimal(0)) { $0 + (weights[$1] ?? 0) }
        let ordered = participants.sorted()
        guard total > 0, let last = ordered.last else { return weights }

        var shares: [ParticipantID: Decimal] = [:]
        var distributed = Decimal(0)
        for id in ordered.dropLast() {
            let share = ((weights[id] ?? 0) / total).rounded(scale: 6, mode: .down)
            shares[id] = share
            distributed += share
        }
        shares[last] = 1 - distributed
        return shares
    }
}

import Foundation

public extension Expense {
    /// El monto a contar en el Dashboard **personal** de quien mira — no el
    /// monto completo del evento. Un gasto compartido guarda el total real
    /// (lo que de verdad se cobró/pagó, necesario para `PersonLedger` y para
    /// el saldo con el banco si fue tarjeta), pero mostrar ese total en el
    /// Dashboard personal de quien lo pagó se ve como si hubiera absorbido
    /// todo el costo — el resto ya está separado como cuenta por cobrar,
    /// contarlo dos veces es el bug real detrás de "se va a mis gastos
    /// personales con toda la cantidad, como si yo hubiera pagado todo".
    ///
    /// - Parameter viewerIdentities: qué participante es "yo" en cada lista
    ///   compartida (`SharedListStore.viewerParticipantID(for:)`, cacheado
    ///   por quien llama — es async en el store real, ADR-0022). Sin
    ///   `sharedListID`, o sin identidad marcada todavía para esa lista,
    ///   regresa el monto completo — el respaldo seguro de siempre, nunca
    ///   `0` ni un crash. El split que se usa es el que quedó congelado en
    ///   el propio evento (ADR-0007), nunca el vigente de la lista.
    func personalAmount(viewerIdentities: [SharedListID: ParticipantID]) -> Money {
        guard
            let sharedListID,
            let split,
            let viewerID = viewerIdentities[sharedListID]
        else { return amount }

        // `.payerOnly` no genera deuda entre nadie (`SplitRule.portions(of:)`
        // regresa `[:]` siempre, a propósito) — el costo real es 100% de
        // quien pagó y 0% de cualquier otro, no "no se pudo resolver".
        if split == .payerOnly {
            return viewerID == payer ? amount : Money.zero(amount.currency)
        }
        // Si el split ni siquiera resuelve, sigue aplicando el respaldo seguro
        // de siempre: el monto completo, nunca `0` ni un crash.
        guard let portions = try? split.portions(of: amount) else { return amount }
        // Pero "el split resolvió y yo no salgo en él" no es un fallo: es un
        // gasto en el que de verdad no participé. Pasa al unirse a una lista
        // después de que un gasto viejo ya congeló su split (ADR-0007) — el
        // split no se recalcula hacia atrás. Contarlo completo le metería al
        // Dashboard un gasto ajeno al 100%, la misma doble contabilidad que
        // esta función existe para evitar.
        return portions[viewerID] ?? Money.zero(amount.currency)
    }
}

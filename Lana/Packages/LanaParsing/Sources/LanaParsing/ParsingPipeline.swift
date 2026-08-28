import Foundation

/// Un `ParsedTransaction` después de la validación determinista: el monto
/// ya pasó por `AmountValidator` (que gana sobre el modelo) y los de
/// monto ≤ 0 ya se descartaron.
public struct ValidatedTransaction: Sendable {
    public let transaction: ParsedTransaction
    public let validatedAmount: Decimal
    public let needsReview: Bool
}

public struct ParsingPipelineResult: Sendable {
    public let transactions: [ValidatedTransaction]
    /// Números que aparecen en el texto pero ningún gasto reclamó. Puede ser
    /// ruido ("2 boletos") o una señal de que el modelo perdió un gasto — es
    /// informativo, no dispara `needsReview` por sí solo
    /// (Docs/DATA-FLOW.md: "es señal, no rechazo").
    public let unclaimedAmounts: [Decimal]
}

/// Los pasos deterministas después del modelo, sin IA de por medio
/// (Docs/DATA-FLOW.md → Validación): el monto del regex gana sobre el del
/// modelo, y un gasto de monto ≤ 0 no existe.
public enum ParsingPipeline {
    /// Valida y filtra `batch` contra `rawText`: el monto de cada transacción
    /// pasa por `AmountValidator`, y las de monto ≤ 0 se descartan.
    public static func process(_ batch: ParsedTransactionBatch, rawText: String) -> ParsingPipelineResult {
        let validator = AmountValidator()
        let foundAmounts = validator.amounts(in: rawText)
        var claimedAmounts: Set<Decimal> = []
        let normalizedRawText = rawText.lowercased()

        let validated: [ValidatedTransaction] = batch.transactions
            .map { transaction -> (ParsedTransaction, AmountValidation) in
                var transaction = transaction
                // El modelo recibe los alias de tarjeta del usuario como
                // contexto (`ParserInstructions.cardSection`) para reusar
                // el nombre correcto — no como una invitación a atribuir
                // una tarjeta a cada gasto. En la práctica a veces sí lo
                // hace: "cardHint" viene lleno aunque el texto nunca
                // mencionó ninguna tarjeta. Mismo principio que ya rige el
                // monto (Docs/CLAUDE.md → "el regex gana sobre el
                // modelo"): si lo que dice el modelo no aparece de verdad
                // en el texto, se descarta — sin tarjeta, `EntryModel`
                // cae a efectivo por default, que es lo correcto.
                if !transaction.cardHint.isEmpty, !normalizedRawText.contains(transaction.cardHint.lowercased()) {
                    transaction.cardHint = ""
                }
                let modelAmount = Decimal(transaction.amount).rounded(scale: 2, mode: .plain)
                return (transaction, validator.validate(modelAmount: modelAmount, in: rawText))
            }
            .filter { _, validation in validation.amount > 0 }
            .map { transaction, validation in
                claimedAmounts.insert(validation.amount)
                return ValidatedTransaction(
                    transaction: transaction,
                    validatedAmount: validation.amount,
                    needsReview: transaction.needsReview || validation.needsReview)
            }

        let unclaimed = foundAmounts.filter { !claimedAmounts.contains($0) }
        return ParsingPipelineResult(transactions: validated, unclaimedAmounts: unclaimed)
    }
}

private extension Decimal {
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}

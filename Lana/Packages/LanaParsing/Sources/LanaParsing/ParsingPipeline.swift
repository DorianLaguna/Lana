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
        let clauses = Self.clauses(in: rawText)
        var clauseCursor = 0

        let validated: [ValidatedTransaction] = batch.transactions
            .map { transaction -> (ParsedTransaction, AmountValidation) in
                var transaction = transaction
                let modelAmount = Decimal(transaction.amount).rounded(scale: 2, mode: .plain)
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
                //
                // La validación es contra la CLÁUSULA de esta transacción,
                // no contra todo el dictado: en un lote ("pica fresa 2,
                // iPhone 703, PPR 2592 con Banamex") el modelo a veces
                // repite la tarjeta mencionada una sola vez en las demás
                // transacciones del lote. Contra el texto completo esa
                // tarjeta sí "aparece" (en la cláusula de otro gasto), así
                // que la guardia no la atrapaba — el bug real detrás de
                // "un cargo recurrente aparece en la tarjeta equivocada".
                let scope = Self.clause(
                    forAmount: modelAmount,
                    in: clauses,
                    validator: validator,
                    cursor: &clauseCursor)
                    ?? rawText
                if !transaction.cardHint.isEmpty, !scope.lowercased().contains(transaction.cardHint.lowercased()) {
                    transaction.cardHint = ""
                }
                // Compartir un gasto no lo decide el modelo solo (ADR-0027).
                // La primera versión de esto (ADR-0025) confiaba en que el
                // modelo llenara `payerHint` únicamente al mencionarse una
                // división — en la práctica lo llenaba con "yo" en casi
                // cualquier "pagué X"/"compré Y", y todos los gastos
                // personales terminaban en la lista compartida. Mismo
                // principio que ya rige el monto (Docs/CLAUDE.md → "el regex
                // gana sobre el modelo"): sin vocabulario de compartir en el
                // texto crudo, no hay gasto compartido, diga lo que diga.
                if transaction.isShared, !Self.mentionsSharing(normalizedRawText) {
                    transaction.isShared = false
                }
                if !transaction.isShared {
                    transaction.payerHint = ""
                    transaction.splitHint = ""
                }
                // Mismo resguardo que `cardHint`: "yo" es la única excepción
                // — nunca aparece como tal en el texto ("pagué yo", "lo puse
                // yo"), así que no se descarta por no calzar literal.
                if !transaction.payerHint.isEmpty, transaction.payerHint.lowercased() != "yo",
                   !normalizedRawText.contains(transaction.payerHint.lowercased()) {
                    transaction.payerHint = ""
                }
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

    /// Vocabulario de "esto se comparte" en español mexicano coloquial. La
    /// lista es a propósito corta y explícita: prefiere no detectar un gasto
    /// compartido (el usuario lo marca a mano, que ya se puede) a mandar un
    /// gasto personal a una lista compartida sin que se haya pedido — eso
    /// último mueve dinero entre personas en los saldos, el error caro.
    /// `contains` sobre la raíz cubre las conjugaciones ("dividimos",
    /// "dividí", "dividido") sin listarlas una por una.
    private static func mentionsSharing(_ normalizedText: String) -> Bool {
        let markers = [
            "compart", // compartido, compartimos, compartir
            "dividi", "dividí", "divid", // dividimos, dividido, división
            "repart", // repartimos, repartido
            "a medias",
            "mitad y mitad",
            "entre los dos", "entre las dos", "entre nosotros",
            "cada quien",
            "me debe", "le debo"
        ]
        return markers.contains { normalizedText.contains($0) }
    }

    /// Parte `text` por la puntuación de lista típica de un dictado con
    /// varias transacciones ("pica fresa 2, iPhone 703.96, PPR 2592 con
    /// Banamex"). A propósito no parte por palabras sueltas como "y" —
    /// esas también aparecen dentro del concepto de un solo gasto ("pan y
    /// mantequilla") y partirían ahí un gasto que en realidad es uno solo.
    ///
    /// Una coma entre dígitos con exactamente tres a la derecha es separador
    /// de miles ("1,200"), no de cláusulas — `AmountValidator` la lee así
    /// (mismo criterio que su propio regex). Partir ahí dejaría "renta 1" y
    /// "200 con Banamex", ninguna con el monto 1200 que el modelo reportó,
    /// así que `clause(forAmount:)` no encontraría cláusula y todo caería al
    /// texto completo — justo el alcance ancho que esto vino a arreglar.
    private static func clauses(in text: String) -> [String] {
        // Separador de verdad = una coma que NO sea de miles, es decir que no
        // venga precedida de dígito o no la sigan exactamente tres.
        let pattern = #"[;\n]|(?<!\d),|,(?!\d{3}(?!\d))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
        }
        var clauses: [String] = []
        var start = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let matchRange = Range(match.range, in: text) else { continue }
            clauses.append(String(text[start ..< matchRange.lowerBound]))
            start = matchRange.upperBound
        }
        clauses.append(String(text[start...]))
        return clauses
    }

    /// Busca, a partir de `cursor`, la primera cláusula que contenga
    /// `amount` tal cual aparece en el texto, y la consume — así dos
    /// transacciones del mismo monto ("café 50, agua 50 con Bancomer") no
    /// reclaman la misma cláusula dos veces, en el mismo orden en que se
    /// dictaron. `nil` si ninguna cláusula por delante calza; quien llama
    /// cae entonces al texto completo, el comportamiento de antes.
    private static func clause(
        forAmount amount: Decimal,
        in clauses: [String],
        validator: AmountValidator,
        cursor: inout Int) -> String? {
        guard cursor < clauses.count else { return nil }
        for index in cursor ..< clauses.count where validator.amounts(in: clauses[index]).contains(amount) {
            cursor = index + 1
            return clauses[index]
        }
        return nil
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

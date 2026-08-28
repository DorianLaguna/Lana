import AppIntents
import Foundation
import LanaCore

/// Falta de match no es ambigüedad de captura (eso se resuelve con
/// `needsReview` — Docs/CLAUDE.md), es un error de configuración del
/// atajo: el usuario nombró la tarjeta distinto en Wallet que en Lana. Se
/// reporta como falla del intent para que lo note al armar el atajo, no
/// se adivina ni se guarda a medias.
enum AddTransactionIntentError: LocalizedError {
    case cardNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .cardNotFound(name):
            "No encontré en Lana ninguna tarjeta que calce con «\(name)». Revisa el alias o los últimos 4 "
                + "dígitos en Ajustes → Tarjetas."
        }
    }
}

/// `Decimal(a Double)` es una conversión binaria exacta del valor del
/// `Double`, no del decimal que se esperaría — la misma trampa que
/// `Money.swift` ya documenta para literales. Redondear a centavos vía
/// texto antes de convertir evita que $149.99 llegue como
/// 149.98999999999998.
private nonisolated func roundedDecimal(_ value: Double) -> Decimal {
    Decimal(string: String(format: "%.2f", value)) ?? Decimal(value)
}

/// Acción de Shortcuts que expone Lana para el trigger de automatización
/// "Wallet" (ADR-0009): no existe API para leer transacciones de Apple Pay,
/// así que el usuario arma un atajo por cada tarjeta física y le conecta el
/// monto, el comercio y el nombre de tarjeta que el propio trigger entrega.
///
/// Solo captura pagos NFC — nada de compras en navegador (ADR-0009). Toda
/// transacción capturada aquí entra con `needsReview: true`, nunca como
/// dato confirmado: el trigger se pasa de tiempo y dispara hasta en pagos
/// rechazados.
struct AddTransactionIntent: AppIntent {
    static let title: LocalizedStringResource = "Agregar transacción de Apple Pay"
    static let description = IntentDescription("""
    Registra en Lana un pago hecho con Apple Pay, para revisarlo después. Arma un atajo por cada \
    tarjeta física, con el trigger de automatización "Wallet", y conecta aquí el monto, el comercio \
    y el nombre de tarjeta que Wallet entrega.
    """)

    /// No abre la app — el punto entero es que esto pase sin que el
    /// usuario la toque (ADR-0009).
    static let openAppWhenRun = false

    @Parameter(title: "Monto")
    var amount: Double

    @Parameter(title: "Comercio")
    var merchant: String

    @Parameter(title: "Tarjeta (como la nombra Wallet)")
    var walletCardName: String

    @Parameter(title: "Fecha de la transacción")
    var transactionDate: Date?

    init() {
        amount = 0
        merchant = ""
        walletCardName = ""
        transactionDate = nil
    }

    func perform() async throws -> some IntentResult {
        let dependencies = try await AppDependencies.live()
        let cards = try await dependencies.cardStore.cards()

        guard let card = Card.bestMatch(for: walletCardName, in: cards) else {
            throw AddTransactionIntentError.cardNotFound(walletCardName)
        }

        let paymentMethod: PaymentMethod = card.kind == .credit
            ? .credit(cardID: card.id)
            : .debit(cardID: card.id)
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let concept = trimmedMerchant.isEmpty ? "Apple Pay" : trimmedMerchant

        // Solo para sugerir categoría — el monto y la fecha ya vienen
        // ciertos de Wallet, nunca se le piden al modelo (a diferencia de
        // la captura por texto, donde "el regex gana sobre el monto" sobre
        // lo que el propio modelo interpretó del mismo texto).
        var category: String?
        var subcategory: String?
        if !trimmedMerchant.isEmpty, await dependencies.parser.availability == .available {
            if let result = try? await dependencies.parser.parse(trimmedMerchant).first {
                category = result.category
                subcategory = result.subcategory
            }
        }

        let expense = Expense(
            kind: .expense,
            amount: Money(amount: roundedDecimal(amount), currency: .mxn),
            concept: concept,
            category: category,
            subcategory: subcategory,
            date: transactionDate ?? Date(),
            paymentMethod: paymentMethod,
            needsReview: true)

        try await dependencies.store.save(expense)
        return .result()
    }
}

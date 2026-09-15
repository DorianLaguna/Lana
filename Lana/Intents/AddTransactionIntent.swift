import AppIntents
import Foundation
import LanaCore
import LanaParsing

/// Falta de match no es ambigüedad de captura (eso se resuelve con
/// `needsReview` — Docs/CLAUDE.md), es un error de configuración del
/// atajo: el usuario nombró la tarjeta distinto en Wallet que en Lana. Se
/// reporta como falla del intent para que lo note al armar el atajo, no
/// se adivina ni se guarda a medias.
///
/// `CustomLocalizedStringResourceConvertible` no es decorativo: App Intents
/// **ignora** `errorDescription` de `LocalizedError` al reportar una falla, y
/// Shortcuts muestra su mensaje genérico ("la app encontró un error"). Sin
/// esta conformidad, todo el diagnóstico de abajo no se lee en ningún lado —
/// que es exactamente lo que pasó al probar un pago real (ADR-0033).
enum AddTransactionIntentError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case cardNotFound(String)
    /// Lleva lo que SÍ llegó, no solo el aviso de lo que faltó: cuando el
    /// atajo se ve bien armado y aun así no funciona, lo único que
    /// distingue "la variable no está conectada" de "la variable está
    /// conectada pero Wallet la entrega vacía" es ver los valores crudos.
    /// Este mensaje se lee en Shortcuts, no en la app — es para quien está
    /// armando la automatización (ADR-0033).
    case missingAmount(received: String)
    /// Cualquier falla al levantar el store dentro del proceso del intent
    /// (Core Data, CloudKit). Se envuelve para que llegue legible a
    /// Shortcuts en vez del genérico del sistema — sin esto, un fallo de
    /// arranque y uno de configuración del atajo se ven idénticos, y no hay
    /// forma de saber cuál de los dos pasó.
    case setupFailed(String)

    /// Una sola redacción para los dos caminos: `String(localized:)` la
    /// deriva del recurso, en vez de tener el mismo texto escrito dos veces
    /// y que uno se corrija sin el otro.
    var errorDescription: String? {
        String(localized: localizedStringResource)
    }

    /// Un literal por caso, sin concatenar con `+`: `LocalizedStringResource`
    /// es `ExpressibleByStringInterpolation`, y un `String` ya concatenado no
    /// convierte — el mismo tropiezo que documenta `IntentDescription`.
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .cardNotFound(name):
            """
            No encontré en Lana ninguna tarjeta que calce con «\(name)». Revisa el alias, el \
            «Nombre en Wallet» o los últimos 4 dígitos en Ajustes → Tarjetas.
            """
        case let .missingAmount(received):
            """
            No me llegó el monto del pago, así que no guardé nada. Esto es lo que recibí del atajo \
            — lo que salga vacío es una variable que Wallet no entregó: \(received)
            """
        case let .setupFailed(reason):
            """
            Lana no pudo abrir tus datos para guardar el pago, así que no guardé nada. Detalle: \
            \(reason)
            """
        }
    }
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
    Registra en Lana un pago hecho con Apple Pay, para revisarlo después. Arma un atajo con el \
    trigger de automatización "Wallet" y conéctale el monto, el comercio y la tarjeta. Si alguna de \
    esas variables llega vacía, conecta la transacción completa al último campo: Lana la interpreta \
    con el mismo parser que la captura por voz.
    """)

    /// No abre la app — el punto entero es que esto pase sin que el
    /// usuario la toque (ADR-0009).
    static let openAppWhenRun = false

    // AL AGREGAR O RENOMBRAR UN `@Parameter` DE ABAJO, actualiza también
    // `ParameterMapping.Parameter` y `parameterMappings` en
    // `GuiaApplePayContent` (LanaCore): esa guía le dice al usuario qué
    // campos conectar en Atajos, con estos títulos textuales. No hay forma
    // de que el compilador lo exija — `@Parameter(title:)` necesita un
    // literal, y este target no se puede probar sin simulador (ADR-0019) —
    // así que esta nota y su gemela allá son la única atadura. Cuando se
    // desincronizaron, la guía enseñó a armar el atajo sin los campos de
    // respaldo y la captura no registraba nada (ADR-0033).

    @Parameter(title: "Monto")
    var amount: Double

    /// Respaldo para cuando el campo numérico llega en cero. Shortcuts
    /// convierte cualquier variable a texto sin problema, pero una cantidad
    /// con moneda ("$149.99") metida en un campo `Double` se pierde y llega
    /// como 0 — el fallo real que reportó el usuario, con el atajo bien
    /// armado. Aquí se conecta la MISMA variable de monto (ADR-0033).
    @Parameter(title: "Monto como texto")
    var amountText: String?

    /// La transacción entera, tal cual la entrega Wallet. Es el respaldo
    /// más amplio: si el comercio o el monto no llegan por sus campos, esto
    /// pasa por el MISMO `parse(_:)` de la captura por voz — que por dentro
    /// corre `ParsingPipeline`, o sea que el monto lo sigue validando el
    /// regex sobre el texto crudo, no el modelo (ADR-0033).
    @Parameter(title: "Transacción completa")
    var transactionText: String?

    @Parameter(title: "Comercio")
    var merchant: String

    @Parameter(title: "Tarjeta (como la nombra Wallet)")
    var walletCardName: String

    @Parameter(title: "Fecha de la transacción")
    var transactionDate: Date?

    init() {
        amount = 0
        amountText = nil
        transactionText = nil
        merchant = ""
        walletCardName = ""
        transactionDate = nil
    }

    func perform() async throws -> some IntentResult {
        let dependencies: AppDependencies
        do {
            // `shared()`, nunca `live()`: si la app sigue viva en segundo
            // plano, ya tiene el store abierto, y un segundo contenedor sobre
            // el mismo archivo es lo que hacía fallar la captura "a veces"
            // (ADR-0041).
            dependencies = try await AppDependencies.shared()
        } catch {
            throw AddTransactionIntentError.setupFailed(error.localizedDescription)
        }
        // Una sola pasada por el parser: de ahí salen monto (ya validado
        // por el regex dentro de `ParsingPipeline`), concepto y categoría.
        let parsed = await Self.parse(transactionText, with: dependencies.parser)

        // Un pago de $0 no existe (mismo criterio que `ParsingPipeline`,
        // que descarta los de monto ≤ 0). Si ningún campo trae monto, el
        // atajo está mal armado o Wallet no lo entregó — un problema de
        // configuración, igual que `cardNotFound`, no una captura ambigua.
        // Guardarlo dejaría un gasto de $0 sin concepto que hay que ir a
        // cazar y borrar; fallar aquí lo dice en Shortcuts, donde sí se
        // puede arreglar. Por eso esto no contradice "guardar nunca se
        // bloquea" (Docs/CLAUDE.md): esa regla es para el parseo ambiguo de
        // una captura real, y aquí no hay nada que capturar.
        guard let resolvedAmount = resolvedAmount(parsed: parsed) else {
            throw AddTransactionIntentError.missingAmount(received: receivedDiagnostic)
        }

        let cards: [Card]
        do {
            cards = try await dependencies.cardStore.cards()
        } catch {
            throw AddTransactionIntentError.setupFailed(error.localizedDescription)
        }
        guard let card = Card.bestMatch(for: walletCardName, in: cards) else {
            throw AddTransactionIntentError.cardNotFound(walletCardName)
        }
        let paymentMethod: PaymentMethod = card.kind == .credit
            ? .credit(cardID: card.id)
            : .debit(cardID: card.id)

        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromMerchant = trimmedMerchant.isEmpty
            ? nil
            : await Self.parse(trimmedMerchant, with: dependencies.parser)
        // El comercio, si llegó, manda sobre lo que el modelo sacó de la
        // transacción completa: es el dato directo, no una interpretación.
        let suggestion = fromMerchant ?? parsed

        let expense = Expense(
            kind: .expense,
            amount: Money(amount: resolvedAmount, currency: .mxn),
            concept: trimmedMerchant.isEmpty ? (parsed?.concept ?? "Apple Pay") : trimmedMerchant,
            category: suggestion?.category,
            subcategory: suggestion?.subcategory,
            date: transactionDate ?? Date(),
            paymentMethod: paymentMethod,
            needsReview: true)

        do {
            try await dependencies.store.save(expense)
        } catch {
            throw AddTransactionIntentError.setupFailed(error.localizedDescription)
        }
        return .result()
    }

    /// El monto, por orden de confianza: el campo numérico, el de texto, lo
    /// que el parser sacó de la transacción (ya pasado por el regex), y como
    /// último recurso el regex crudo sobre la transacción —  solo si trae
    /// UN número: en un texto con varios (unos últimos 4 dígitos, un folio)
    /// no hay forma de saber cuál es el monto, y adivinar dinero no se hace
    /// (ADR-0033).
    private func resolvedAmount(parsed: ParseResult?) -> Decimal? {
        let validator = AmountValidator()
        if let direct = validator.resolveAmount(numeric: amount, text: amountText) {
            return direct
        }
        if let parsedAmount = parsed?.amount?.amount, parsedAmount > 0 {
            return parsedAmount
        }
        guard let transactionText else { return nil }
        let found = validator.amounts(in: transactionText).filter { $0 > 0 }
        return found.count == 1 ? found[0] : nil
    }

    /// `nil` si no hay texto que parsear o si el modelo no está disponible —
    /// se checa `availability` antes de crear la sesión (Docs/CLAUDE.md), y
    /// que el modelo falte nunca puede tumbar la captura: el monto sigue
    /// saliendo del regex.
    private static func parse(_ text: String?, with parser: any ExpenseParsing) async -> ParseResult? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard await parser.availability == .available else { return nil }
        return try? await parser.parse(text).first
    }

    /// Los valores crudos que entregó el atajo, para el mensaje de error.
    /// Entre comillas a propósito: sin ellas no se distingue una cadena
    /// vacía de un espacio, que es justo lo que hay que ver aquí.
    private var receivedDiagnostic: String {
        "Monto=\(amount), Monto como texto=«\(amountText ?? "")», "
            + "Comercio=«\(merchant)», Tarjeta=«\(walletCardName)», "
            + "Transacción=«\(transactionText ?? "")»"
    }
}

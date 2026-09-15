import Foundation

// MARK: - Nested content types

// Los tipos de valor que componen el contenido estático de la guía de Apple
// Pay. El struct contenedor `GuiaApplePayContent` y su instancia `.standard`
// se definen aparte; aquí viven solo sus piezas. Todo es dato puro —
// `Sendable`, `Equatable`, e `Identifiable` donde el orden importa — sin
// lógica, para poder probar completitud del contenido sin renderizar UI
// (ADR-0009, ADR-0019, ADR-0031).

/// Un paso numerado de la secuencia de Atajos (R2.1).
public struct GuiaStep: Sendable, Equatable, Identifiable {
    /// Orden 1-based; es la "numeración" que exige R2.1.
    public let id: Int
    public let title: String
    public let detail: String
    public let systemImage: String
    /// Este paso lleva colgado el mapeo de parámetros (R2.3) — el que agrega
    /// la acción de Lana, donde el usuario conecta cada dato de Wallet.
    ///
    /// Es un dato y no una deducción del texto: la vista lo detectaba
    /// buscando una frase dentro de `detail`, así que reescribir el copy
    /// borraba de la guía el mapeo que ADR-0033 marca como imprescindible,
    /// en silencio y sin romper ninguna prueba.
    public let attachesParameterMapping: Bool

    public init(
        id: Int,
        title: String,
        detail: String,
        systemImage: String,
        attachesParameterMapping: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.attachesParameterMapping = attachesParameterMapping
    }
}

/// El mapeo Wallet → App Intent para un parámetro (R2.3).
///
/// **No es una biyección.** La primera versión asumía uno a uno
/// (monto→monto, comercio→comercio, tarjeta→tarjeta) y por eso omitía los
/// dos campos que ADR-0033 agregó para que la captura sobreviva cuando
/// Wallet entrega variables vacías: la MISMA variable de monto se conecta a
/// dos campos distintos del intent («Monto» y «Monto como texto»). Un
/// usuario que siguiera la guía armaba justo la configuración que ya está
/// documentada como rota.
///
/// Cada caso de `Parameter` corresponde a un `@Parameter` de
/// `AddTransactionIntent`. **Al agregar uno allá, agrégalo aquí**: no hay
/// forma de que el compilador lo exija (el intent vive en el target de la
/// app, que no se puede probar sin simulador, ADR-0019), así que este
/// comentario y el gemelo en `AddTransactionIntent` son la única atadura.
public struct ParameterMapping: Sendable, Equatable, Identifiable {
    /// Los campos de la acción de Lana. `fullTransaction` y `amountText` son
    /// los respaldos de ADR-0033; `date` no se lista porque se deja vacío a
    /// propósito (el intent cae a la hora de ejecución).
    public enum Parameter: String, Sendable, CaseIterable {
        case amount // monto
        case amountText // monto como texto (respaldo, ADR-0033)
        case fullTransaction // transacción completa (respaldo, ADR-0033)
        case merchant // comercio
        case cardName // nombre de tarjeta
    }

    /// Identifica por el campo del intent, no por la variable de Wallet: una
    /// misma variable alimenta dos campos, así que la de Wallet se repite.
    public var id: Parameter {
        intentParameter
    }

    public let walletParameter: Parameter
    public let intentParameter: Parameter
    /// Como lo nombra Wallet en la app Atajos. Los nombres reales que
    /// reportó el usuario en su iPhone («Cantidad pago», «Tarjeta o pase»),
    /// no genéricos: son la única evidencia de campo que tenemos.
    public let walletLabel: String
    /// El título exacto del `@Parameter`, tal cual se lee en Atajos —
    /// literalmente lo que el usuario tiene que buscar en pantalla.
    public let intentLabel: String

    public init(
        walletParameter: Parameter,
        intentParameter: Parameter,
        walletLabel: String,
        intentLabel: String) {
        self.walletParameter = walletParameter
        self.intentParameter = intentParameter
        self.walletLabel = walletLabel
        self.intentLabel = intentLabel
    }
}

/// Explicación de emparejamiento de tarjetas (R3).
public struct MatchingExplanation: Sendable, Equatable {
    /// Señales en orden de prioridad: últimos 4 dígitos primero, luego
    /// alias / nombre en Wallet (R3.1).
    public let prioritySignals: [MatchSignal]
    /// Los pasos concretos para encontrar el nombre con el que Wallet reporta
    /// la tarjeta — el dato que hay que registrar en «Nombre en Wallet». Son
    /// pasos numerados (no un párrafo) porque el nombre no está a la vista:
    /// vive detrás de «Detalles de la tarjeta», y un texto corrido dejaba al
    /// usuario sin saber dónde tocar. Es el hueco real de la guía: sabía QUÉ
    /// registrar, no DÓNDE verlo.
    public let findNameSteps: [GuiaStep]
    /// Qué hacer cuando el nombre en Wallet difiere del alias: registrar
    /// `walletMatchHint` (R3.2).
    public let mismatchGuidance: String
    /// Qué revisar si ninguna tarjeta empareja (R3.3).
    public let noMatchGuidance: String

    public init(
        prioritySignals: [MatchSignal],
        findNameSteps: [GuiaStep],
        mismatchGuidance: String,
        noMatchGuidance: String) {
        self.prioritySignals = prioritySignals
        self.findNameSteps = findNameSteps
        self.mismatchGuidance = mismatchGuidance
        self.noMatchGuidance = noMatchGuidance
    }
}

/// Una señal de emparejamiento, ordenada por prioridad (R3.1).
public struct MatchSignal: Sendable, Equatable, Identifiable {
    /// 0-based; define el orden de prioridad (índice 0 == últimos 4 dígitos).
    public let id: Int
    public let name: String
    public let explanation: String

    public init(id: Int, name: String, explanation: String) {
        self.id = id
        self.name = name
        self.explanation = explanation
    }
}

/// Una limitación conocida de la captura automática (R4).
public struct KnownLimitation: Sendable, Equatable, Identifiable {
    /// Los seis casos que R4 exige comunicar.
    public enum Kind: String, Sendable, CaseIterable {
        case nfcOnly // solo NFC, navegador no (R4.1)
        case needsReview // todo entra needsReview (R4.2)
        case rejectedTx // puede registrar rechazadas (R4.3)
        case duplicateTx // puede registrar duplicadas (R4.4)
        case reviewEach // revisar cada transacción (R4.5)
        case manualIsPrimary // manual sigue siendo el camino principal (R4.6)
        /// Wallet puede entregar el monto y el comercio vacíos al momento
        /// del tap; entonces no se registra nada (ADR-0033). No estaba en
        /// R4 porque la spec es anterior a haberlo reproducido.
        case emptyWalletVariables
    }

    /// El `kind` identifica la limitación — hay exactamente una por caso.
    public var id: Kind {
        kind
    }

    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}

/// Requisito de dispositivo físico y limitación del simulador (R5).
public struct DeviceRequirement: Sendable, Equatable {
    /// Requiere dispositivo físico + al menos una tarjeta en Wallet (R5.1).
    public let physicalDeviceMessage: String
    /// No puede probarse en el simulador de iOS (R5.2).
    public let simulatorMessage: String

    public init(physicalDeviceMessage: String, simulatorMessage: String) {
        self.physicalDeviceMessage = physicalDeviceMessage
        self.simulatorMessage = simulatorMessage
    }
}

// MARK: - Content container

/// Contenido estático de toda la `Guia_ApplePay`. Es un valor `Sendable`,
/// construido una sola vez (`.standard`) y compartido: ningún texto de la guía
/// vive hardcodeado en las vistas, todo sale de aquí. Así se prueba la
/// completitud del contenido (todos los pasos, mapeo completo de parámetros,
/// todas las limitaciones) sin renderizar UI (ADR-0009, ADR-0019, ADR-0031).
public struct GuiaApplePayContent: Sendable, Equatable {
    /// Requisitos de dispositivo físico y limitación del simulador (R5).
    public let deviceRequirement: DeviceRequirement
    /// Pasos numerados y ordenados para armar la automatización (R2).
    public let shortcutSteps: [GuiaStep]
    /// Mapeo de cada parámetro de Wallet al parámetro del App Intent (R2.3).
    public let parameterMappings: [ParameterMapping]
    /// Explicación de emparejamiento y su orden de prioridad (R3).
    public let matching: MatchingExplanation
    /// Limitaciones conocidas de la captura automática (R4).
    public let limitations: [KnownLimitation]

    public init(
        deviceRequirement: DeviceRequirement,
        shortcutSteps: [GuiaStep],
        parameterMappings: [ParameterMapping],
        matching: MatchingExplanation,
        limitations: [KnownLimitation]) {
        self.deviceRequirement = deviceRequirement
        self.shortcutSteps = shortcutSteps
        self.parameterMappings = parameterMappings
        self.matching = matching
        self.limitations = limitations
    }
}

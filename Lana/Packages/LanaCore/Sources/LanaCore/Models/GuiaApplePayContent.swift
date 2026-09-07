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

    public init(id: Int, title: String, detail: String, systemImage: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
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
    /// Qué hacer cuando el nombre en Wallet difiere del alias: registrar
    /// `walletMatchHint` (R3.2).
    public let mismatchGuidance: String
    /// Qué revisar si ninguna tarjeta empareja (R3.3).
    public let noMatchGuidance: String

    public init(
        prioritySignals: [MatchSignal],
        mismatchGuidance: String,
        noMatchGuidance: String) {
        self.prioritySignals = prioritySignals
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

// MARK: - Standard content

public extension GuiaApplePayContent {
    /// El contenido real de producción — la única instancia que la app usa.
    /// Todo el texto es en español (Docs/CONVENTIONS.md).
    static let standard = GuiaApplePayContent(
        deviceRequirement: DeviceRequirement(
            physicalDeviceMessage: """
            La captura automática de Apple Pay requiere un iPhone físico con al \
            menos una tarjeta agregada a Wallet. Sin una tarjeta en Wallet, el \
            disparador de Atajos nunca se activa.
            """,
            simulatorMessage: """
            Esta función no puede probarse en el simulador de iOS: el simulador \
            no permite agregar tarjetas a la Wallet, así que el pago con Apple \
            Pay y su automatización no ocurren ahí. Prueba siempre en un \
            dispositivo real.
            """),
        // R2.1: pasos numerados 1..n, consecutivos y ordenados. Cubren como
        // mínimo abrir Atajos, crear automatización, seleccionar el disparador
        // Wallet, agregar la acción del App Intent y guardar.
        shortcutSteps: [
            GuiaStep(
                id: 1,
                title: "Abre la app Atajos",
                detail: """
                Busca la app Atajos en tu iPhone y ábrela. Es la app de Apple \
                donde se crean las automatizaciones.
                """,
                systemImage: "square.stack.3d.up"),
            GuiaStep(
                id: 2,
                title: "Crea una automatización nueva",
                detail: """
                Ve a la pestaña Automatización y toca el botón para crear una \
                automatización personal nueva.
                """,
                systemImage: "plus.circle"),
            GuiaStep(
                id: 3,
                title: "Selecciona el disparador Wallet",
                detail: """
                Elige el disparador «Wallet» y selecciona la tarjeta cuyos \
                pagos quieres capturar. Este disparador se activa cuando pagas \
                por contacto (NFC) con esa tarjeta.
                """,
                systemImage: "creditcard"),
            GuiaStep(
                id: 4,
                title: "Agrega la acción de Lana",
                detail: """
                En las acciones de la automatización, busca y agrega \
                «Agregar transacción de Apple Pay» de Lana. Conecta el monto, \
                el comercio y la tarjeta que entrega Wallet. Conecta además la \
                MISMA variable de monto a «Monto como texto», y la transacción \
                completa a «Transacción completa»: son respaldos, y sin ellos, \
                si Wallet entrega el monto vacío, el pago no se registra.
                """,
                systemImage: "arrow.triangle.branch"),
            GuiaStep(
                id: 5,
                title: "Configura para ejecutarse de inmediato",
                detail: """
                Desactiva «Preguntar antes de ejecutar» para que la \
                automatización corra sola, sin pedir confirmación y sin abrir \
                Lana. Así la transacción se captura en segundo plano.
                """,
                systemImage: "bolt"),
            GuiaStep(
                id: 6,
                title: "Guarda la automatización",
                detail: """
                Guarda la automatización. Repite estos pasos creando una \
                automatización independiente por cada tarjeta física que \
                quieras capturar, nombrando cada una con su tarjeta.
                """,
                systemImage: "checkmark.circle")
        ],
        // Un mapeo por cada `@Parameter` de `AddTransactionIntent`, con su
        // título textual — el usuario los busca en pantalla, así que
        // aproximarlos no sirve. La variable de monto aparece dos veces a
        // propósito: alimenta el campo numérico y el de respaldo (ADR-0033).
        parameterMappings: [
            ParameterMapping(
                walletParameter: .amount,
                intentParameter: .amount,
                walletLabel: "Cantidad pago",
                intentLabel: "Monto"),
            ParameterMapping(
                walletParameter: .amount,
                intentParameter: .amountText,
                walletLabel: "Cantidad pago (la misma)",
                intentLabel: "Monto como texto"),
            ParameterMapping(
                walletParameter: .fullTransaction,
                intentParameter: .fullTransaction,
                walletLabel: "Transacción",
                intentLabel: "Transacción completa"),
            ParameterMapping(
                walletParameter: .merchant,
                intentParameter: .merchant,
                walletLabel: "Comercio",
                intentLabel: "Comercio"),
            ParameterMapping(
                walletParameter: .cardName,
                intentParameter: .cardName,
                walletLabel: "Tarjeta o pase",
                intentLabel: "Tarjeta (como la nombra Wallet)")
        ],
        // R3.1: señales en orden de prioridad, últimos 4 dígitos primero
        // (índice 0), luego alias / NombreEnWallet.
        matching: MatchingExplanation(
            prioritySignals: [
                MatchSignal(
                    id: 0,
                    name: "Últimos 4 dígitos",
                    explanation: """
                    Lana empareja primero por los últimos 4 dígitos de la \
                    tarjeta que reporta Wallet. Es la señal de mayor prioridad \
                    y la más confiable.
                    """),
                MatchSignal(
                    id: 1,
                    name: "Alias o Nombre en Wallet",
                    explanation: """
                    Si los dígitos no coinciden, Lana compara el nombre que \
                    reporta Wallet contra el alias de la tarjeta. Si le \
                    registraste un «Nombre en Wallet», usa ese EN LUGAR del \
                    alias, no además: déjalo vacío si el alias ya coincide.
                    """)
            ],
            // R3.2: si el nombre en Wallet difiere del alias, registrar el
            // campo NombreEnWallet (walletMatchHint) en Ajustes → Tarjetas.
            mismatchGuidance: """
            Si el nombre que Wallet reporta para tu tarjeta es distinto del \
            alias visible en Lana, abre Ajustes → Tarjetas y escribe ese \
            nombre exacto en el campo «Nombre en Wallet». Ojo: al llenarlo, \
            ese campo reemplaza al alias para emparejar, así que una errata \
            ahí rompe un emparejamiento que antes funcionaba.
            """,
            // R3.3: si nada empareja, revisar alias, NombreEnWallet y
            // últimos 4 dígitos en Ajustes → Tarjetas.
            noMatchGuidance: """
            Si ninguna tarjeta empareja con lo que reporta Wallet, la \
            automatización falla y no se registra el pago. Revisa en \
            Ajustes → Tarjetas el alias, el Nombre en Wallet y los últimos 4 \
            dígitos de tus tarjetas para corregir el emparejamiento.
            """),
        // R4.1–R4.6: exactamente una entrada por cada uno de los seis casos.
        limitations: [
            KnownLimitation(
                kind: .nfcOnly,
                message: """
                Solo se capturan automáticamente los pagos por contacto (NFC) \
                con el iPhone. Las compras hechas en el navegador no se \
                capturan por esta vía y debes registrarlas manualmente.
                """),
            KnownLimitation(
                kind: .needsReview,
                message: """
                Toda transacción capturada por esta vía entra marcada para \
                revisión (needsReview) y requiere que la revises manualmente \
                antes de considerarla confirmada.
                """),
            KnownLimitation(
                kind: .rejectedTx,
                message: """
                El disparador de Wallet puede registrar pagos que en realidad \
                fueron rechazados, por fallas conocidas del propio disparador.
                """),
            KnownLimitation(
                kind: .duplicateTx,
                message: """
                El disparador de Wallet puede registrar transacciones \
                duplicadas, por fallas conocidas del propio disparador.
                """),
            KnownLimitation(
                kind: .reviewEach,
                message: """
                Por esas fallas conocidas, revisa cada transacción capturada: \
                confirma que el monto, el comercio y la tarjeta sean correctos \
                y descarta las rechazadas o duplicadas.
                """),
            KnownLimitation(
                kind: .emptyWalletVariables,
                message: """
                A veces Wallet entrega el monto o el comercio vacíos al \
                momento del pago. Cuando falta el monto no se registra nada, \
                y el aviso aparece en la app Atajos, no en Lana. Por eso vale \
                la pena conectar «Monto como texto» y «Transacción completa»: \
                son los respaldos con los que Lana puede rescatar el dato.
                """),
            KnownLimitation(
                kind: .manualIsPrimary,
                message: """
                La captura automática es solo una conveniencia. La captura \
                manual sigue siendo el camino principal y obligatorio para \
                registrar tus gastos con certeza.
                """)
        ])
}

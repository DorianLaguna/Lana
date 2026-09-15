import Foundation

// El contenido real de producción de la `Guia_ApplePay` — la única instancia
// que la app usa, aparte de sus tipos (`GuiaApplePayContent.swift`) tal como
// dice el encabezado de aquel archivo. Es puro texto en español
// (Docs/CONVENTIONS.md): cambiar una palabra de la guía se hace aquí, sin
// abrir ninguna vista.

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
                systemImage: "arrow.triangle.branch",
                attachesParameterMapping: true),
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
            // El paso que faltaba: dónde ver el nombre que Wallet le da a la
            // tarjeta, para poder registrarlo en «Nombre en Wallet». El nombre
            // no está a la vista — vive detrás de «Detalles de la tarjeta» —
            // así que va en pasos numerados, no en un párrafo. Pasos reales
            // reportados por un usuario en su iPhone.
            findNameSteps: [
                GuiaStep(
                    id: 1,
                    title: "Abre Cartera y toca tu tarjeta",
                    detail: """
                    En la app Cartera (Wallet), toca la tarjeta cuyo nombre \
                    quieres encontrar. Se abren sus transacciones recientes.
                    """,
                    systemImage: "wallet.pass"),
                GuiaStep(
                    id: 2,
                    title: "Abre «Detalles de la tarjeta»",
                    detail: """
                    Toca los tres puntos (•••) arriba a la derecha y elige \
                    «Detalles de la tarjeta».
                    """,
                    systemImage: "ellipsis.circle"),
                GuiaStep(
                    id: 3,
                    title: "Copia el nombre bajo la tarjeta",
                    detail: """
                    Debajo de la imagen de la tarjeta aparece su nombre. Ese \
                    es el texto exacto que va en «Nombre en Wallet» dentro de \
                    Lana.
                    """,
                    systemImage: "textformat")
            ],
            // R3.2: un pago cayó en la tarjeta equivocada — corregir el
            // «Nombre en Wallet» en la pestaña Tarjetas.
            mismatchGuidance: """
            Un pago se registró en la tarjeta equivocada. Ve a la pestaña \
            Tarjetas, abre la tarjeta correcta y revisa que su «Nombre en \
            Wallet» sea idéntico al que viste en Cartera. Una sola letra o \
            acento de diferencia hace que empareje con otra.
            """,
            // R3.3: nada se registró — revisar los datos de la tarjeta en la
            // pestaña Tarjetas.
            noMatchGuidance: """
            Pagaste pero no apareció ningún gasto. Ve a la pestaña Tarjetas, \
            abre esa tarjeta y verifica sus últimos 4 dígitos y su «Nombre en \
            Wallet». Si ninguno coincide con lo que reporta Cartera, Lana no \
            sabe a qué tarjeta cargar el pago y no lo registra.
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

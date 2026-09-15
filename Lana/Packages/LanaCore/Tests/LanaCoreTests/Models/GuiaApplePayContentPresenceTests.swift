import Foundation
import Testing
@testable import LanaCore

/// Tests de ejemplo (no por propiedad) para la presencia de contenido clave en
/// `GuiaApplePayContent.standard`. Verifican, con comprobaciones de subcadena
/// contra el texto real de la guía, que el contenido cubra los requisitos:
/// R2.2, R2.4, R2.5, R3.2, R3.3, R5.1 y R5.2. No renderizan UI; solo inspeccionan
/// el dato estático.
@Suite("Guía Apple Pay — presencia de contenido")
struct GuiaApplePayContentPresenceTests {
    private let content = GuiaApplePayContent.standard

    // R2.2: la guía indica invocar el App Intent con el título exacto
    // "Agregar transacción de Apple Pay".
    //
    // Se busca en los PASOS, no en las etiquetas de parámetro: el nombre de
    // la acción es lo que el usuario teclea al buscarla en Atajos (paso 4),
    // mientras que `intentLabel` es el título textual de cada campo dentro
    // de la acción ya agregada. Antes se exigía que el nombre de la acción
    // apareciera embebido en cada etiqueta ("Monto de «Agregar transacción
    // de Apple Pay»"), lo que hacía que ninguna etiqueta fuera el título
    // real del campo — y el usuario buscaba en pantalla algo inexistente.
    @Test("R2.2 · El título exacto del App Intent aparece en los pasos")
    func tituloExactoDelIntentAparece() {
        let tituloExacto = "Agregar transacción de Apple Pay"
        let textoDePasos = content.shortcutSteps
            .map { "\($0.title) \($0.detail)" }
            .joined(separator: " ")
        #expect(textoDePasos.contains(tituloExacto))
    }

    /// El mapeo de parámetros (R2.3) cuelga de exactamente un paso: el que
    /// agrega la acción de Lana, que es donde se conectan los datos. Antes la
    /// vista lo deducía buscando una frase dentro del `detail`, así que
    /// reescribir el copy lo borraba de la guía sin romper nada; ahora es un
    /// dato, y esta prueba es la que se cae si alguien lo pierde o lo duplica.
    @Test("Exactamente un paso lleva el mapeo de parámetros, y es el de la acción de Lana")
    func unSoloPasoLlevaElMapeoDeParametros() {
        let conMapeo = content.shortcutSteps.filter(\.attachesParameterMapping)
        #expect(conMapeo.count == 1)
        #expect(conMapeo.first?.detail.contains("Agregar transacción de Apple Pay") == true)
    }

    // R2.4: crear una automatización independiente por cada tarjeta.
    @Test("R2.4 · Los pasos indican una automatización por cada tarjeta")
    func indicaUnaAutomatizacionPorTarjeta() {
        let textoDePasos = content.shortcutSteps
            .map { "\($0.title) \($0.detail)" }
            .joined(separator: " ")
        #expect(textoDePasos.contains("automatización independiente"))
        #expect(textoDePasos.contains("por cada tarjeta"))
    }

    // R2.5: la automatización debe ejecutarse sin pedir confirmación.
    @Test("R2.5 · Los pasos indican ejecutar sin confirmación")
    func indicaEjecutarSinConfirmacion() {
        let textoDePasos = content.shortcutSteps
            .map { "\($0.title) \($0.detail)" }
            .joined(separator: " ")
        #expect(textoDePasos.contains("Preguntar antes de ejecutar"))
        #expect(textoDePasos.contains("sin pedir confirmación"))
    }

    // R3.2: si el nombre en Wallet difiere del alias, registrar el campo
    // "Nombre en Wallet" (walletMatchHint).
    @Test("R3.2 · La guía de mismatch referencia «Nombre en Wallet»")
    func mismatchReferenciaNombreEnWallet() {
        #expect(content.matching.mismatchGuidance.contains("Nombre en Wallet"))
    }

    // R3.3: si nada se registró, revisar los datos de emparejamiento de la
    // tarjeta — Nombre en Wallet y últimos 4 dígitos.
    @Test("R3.3 · La guía de no-match referencia Nombre en Wallet y últimos 4 dígitos")
    func noMatchReferenciaNombreYUltimos4() {
        let guia = content.matching.noMatchGuidance
        #expect(guia.contains("Nombre en Wallet"))
        #expect(guia.contains("últimos 4"))
    }

    /// Dónde encontrar el nombre de la tarjeta en Wallet — el dato de entrada
    /// para «Nombre en Wallet». Son pasos numerados (no está a la vista, vive
    /// tras «Detalles de la tarjeta»): deben tener ids 1-based consecutivos,
    /// pasar por Detalles de la tarjeta y terminar nombrando el campo destino.
    @Test("Los pasos de «cómo se llama en Wallet» están numerados y cubren el camino")
    func findNameStepsNumeradosYCubrenElCamino() {
        let steps = content.matching.findNameSteps
        #expect(steps.count >= 2)
        // Ids 1-based consecutivos, como los pasos de Atajos.
        #expect(steps.map(\.id) == Array(1 ... steps.count))

        let texto = steps.map { "\($0.title) \($0.detail)" }.joined(separator: " ")
        #expect(texto.contains("Cartera") || texto.contains("Wallet"))
        #expect(texto.contains("Detalles de la tarjeta"))
        #expect(texto.contains("Nombre en Wallet"))
    }

    /// R5.1 / R5.2: los mensajes de dispositivo físico y simulador no están
    /// vacíos.
    @Test("R5.1 y R5.2 · Los mensajes de dispositivo físico y simulador no están vacíos")
    func mensajesDeDispositivoNoVacios() {
        #expect(!content.deviceRequirement.physicalDeviceMessage.isEmpty)
        #expect(!content.deviceRequirement.simulatorMessage.isEmpty)
    }
}

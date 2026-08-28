import FoundationModels

/// Las categorías cerradas de un gasto. Once valores; el usuario no puede
/// crear ni eliminar ninguno (ADR-0011) — lo abierto es la subcategoría.
///
/// Lista provisional (2026-08-26, ampliada 2026-08-27 con `regalos` y
/// `educacion`): se fijó con 7 categorías ya vistas en el golden set más
/// `salud` y `servicios`. El dueño del producto planea ampliarla más
/// adelante — cuando eso pase, es un cambio de enum, no de arquitectura.
///
/// Duplicada como `LanaCore.SuggestedCategory` (mismos once raw values) —
/// `LanaCore` no puede depender de `FoundationModels`, así que no hay forma
/// de compartir este tipo directamente. Si esta lista cambia, esa también.
@Generable
public enum ExpenseCategory: String, Sendable, CaseIterable, Codable {
    case comida
    case despensa
    case transporte
    case hogar
    case personal
    case ocio
    case salud
    case servicios
    case regalos
    case educacion
    case otro
}

extension ExpenseCategory {
    /// El `@Guide` no puede ir por-caso en un enum `@Generable` (solo en
    /// stored properties) — por eso la definición de cada categoría vive
    /// aquí, como una constante que el campo `category` de `ParsedTransaction`
    /// referencia. Cero cifras, solo reglas abstractas (ADR-0013).
    static let guideDescription = """
    La categoría del gasto. Once valores posibles, cada uno con un uso claro:
    - comida: un platillo hecho por alguien más para comer ya, en el momento \
    — un restaurante, un puesto callejero, comida rápida, un domicilio de \
    comida ya lista. La señal es que alguien más lo preparó y se come de \
    inmediato. También son comida los dulces y golosinas, aunque vengan \
    empacados y se hayan comprado en tienda — es la única excepción a la \
    regla de "dónde se compró" de despensa.
    - despensa: cualquier producto empacado, envasado o embolsado que se \
    compra en una tienda, súper o changarro — refrescos, botanas saladas, \
    frutas, verduras, abarrotes. La señal es que viene empacado y se \
    compró en un establecimiento de venta, sin importar si se come de \
    inmediato o después. Los dulces y golosinas son la excepción: van en \
    comida, no aquí (ver arriba).
    - transporte: traslados (Uber, taxi, transporte público) y todo lo del \
    vehículo propio — gasolina, casetas, estacionamiento, mantenimiento.
    - hogar: la vivienda misma — muebles, reparaciones, artículos del hogar \
    que no se consumen.
    - personal: cuidado del propio cuerpo y apariencia que no es \
    tratamiento médico — ropa, belleza, accesorios, ejercicio, gimnasio.
    - ocio: entretenimiento — cine, salidas, hobbies, viajes, streaming, \
    videojuegos, actividades al aire libre.
    - salud: consultas médicas, medicinas, tratamientos, seguros de salud.
    - servicios: pagos recurrentes de la vivienda — luz, agua, internet, \
    renta, deudas, suscripciones que no son de entretenimiento.
    - regalos: algo comprado para dárselo a alguien más — cumpleaños, \
    boda, aguinaldo para terceros, cualquier ocasión. La señal es que el \
    destino final no es quien paga.
    - educacion: colegiaturas, cursos, talleres, certificaciones, útiles \
    y libros para aprender algo — no libros de entretenimiento, esos son \
    ocio.
    - otro: solo si ninguna de las anteriores aplica con claridad.

    Si dudas entre comida y despensa, la pregunta decisiva es dónde se \
    compró, no qué tan antojable ni qué tan barato es: tienda o súper es \
    despensa; restaurante, puesto o domicilio de comida ya preparada es \
    comida — con una única excepción: un dulce, chicle o golosina siempre \
    es comida, aunque venga empacado y se haya comprado en tienda. Una \
    botana salada, un refresco o un abarrote sí siguen la regla normal de \
    dónde se compró: despensa.
    """
}

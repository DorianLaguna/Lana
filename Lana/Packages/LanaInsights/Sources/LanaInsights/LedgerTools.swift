import Foundation
import FoundationModels
import LanaCore

/// Las `Tool` que el modelo puede llamar para contestar una pregunta.
///
/// Cada una es un envoltorio delgado sobre un método de `LedgerToolbox`, que es
/// donde de verdad se calcula. Aquí solo viven el esquema de argumentos y la
/// descripción que el modelo lee — y ninguna de las dos cosas contiene cifras
/// del usuario (ADR-0013).
///
/// El modelo elige la herramienta y sus argumentos; el resultado que recibe ya
/// viene formateado en texto. Nunca ve el historial crudo ni un `Decimal`
/// suelto que pudiera querer operar (Docs/CLAUDE.md).
enum LedgerTools {
    static func all(for toolbox: LedgerToolbox) -> [any Tool] {
        [
            TotalPorCategoriaTool(toolbox: toolbox),
            ComparaMesesTool(toolbox: toolbox),
            MayoresGastosTool(toolbox: toolbox),
            SaldoDeListaTool(toolbox: toolbox),
            DeudaPorTarjetaTool(toolbox: toolbox),
            DisponibleProyectadoTool(toolbox: toolbox),
            OrigenDelIngresoTool(toolbox: toolbox)
        ]
    }
}

/// Un mes concreto. El modelo lo llena con el mes que el usuario nombró, o con
/// el mes de hoy, que viaja en el prompt — no lo calcula ni lo adivina.
@Generable
struct MonthArguments: Sendable {
    @Guide(description: "El año de cuatro dígitos del mes que se pregunta.")
    var year: Int

    @Guide(description: "El número del mes, de 1 (enero) a 12 (diciembre).")
    var month: Int
}

struct TotalPorCategoriaTool: Tool {
    let toolbox: LedgerToolbox

    let name = "totalPorCategoria"
    let description = """
    Cuánto se gastó en un mes, desglosado por categoría y separado por moneda. \
    Úsala cuando pregunten en qué se fue el dinero de un mes, o cuánto gastaron \
    en una categoría.
    """

    func call(arguments: MonthArguments) async throws -> String {
        await toolbox.totalPorCategoria(year: arguments.year, month: arguments.month)
    }
}

/// Dos meses a comparar.
@Generable
struct TwoMonthsArguments: Sendable {
    @Guide(description: "El año del primer mes, el más reciente de los dos.")
    var year: Int

    @Guide(description: "El número del primer mes, de 1 a 12.")
    var month: Int

    @Guide(description: "El año del segundo mes, contra el que se compara.")
    var comparedToYear: Int

    @Guide(description: "El número del segundo mes, de 1 a 12.")
    var comparedToMonth: Int
}

struct ComparaMesesTool: Tool {
    let toolbox: LedgerToolbox

    let name = "comparaMeses"
    let description = """
    Compara el gasto de dos meses y dice cuánto cambió y qué categorías subieron \
    o bajaron. Úsala cuando pregunten si gastaron más o menos que otro mes.
    """

    func call(arguments: TwoMonthsArguments) async throws -> String {
        await toolbox.comparaMeses(
            yearA: arguments.year,
            monthA: arguments.month,
            yearB: arguments.comparedToYear,
            monthB: arguments.comparedToMonth)
    }
}

/// Un mes y cuántos movimientos listar.
@Generable
struct TopExpensesArguments: Sendable {
    @Guide(description: "El año de cuatro dígitos del mes que se pregunta.")
    var year: Int

    @Guide(description: "El número del mes, de 1 a 12.")
    var month: Int

    @Guide(description: "Cuántos movimientos listar. Si no lo pidieron, usa cinco.")
    var limit: Int
}

struct MayoresGastosTool: Tool {
    let toolbox: LedgerToolbox

    let name = "mayoresGastos"
    let description = """
    Los movimientos más grandes de un mes, uno por uno con su concepto. Úsala \
    cuando pregunten en qué se les fue más, o cuál fue su gasto más grande.
    """

    func call(arguments: TopExpensesArguments) async throws -> String {
        await toolbox.mayoresGastos(year: arguments.year, month: arguments.month, limit: arguments.limit)
    }
}

/// El nombre de una lista compartida.
@Generable
struct SharedListArguments: Sendable {
    @Guide(description: "El nombre de la lista compartida, tal como lo dijo la persona.")
    var name: String
}

struct SaldoDeListaTool: Tool {
    let toolbox: LedgerToolbox

    let name = "saldoDeLista"
    let description = """
    Quién le debe a quién en una lista compartida, ya simplificado. Úsala cuando \
    pregunten por deudas con personas. Esta deuda es entre personas y nunca se \
    suma con la de las tarjetas.
    """

    func call(arguments: SharedListArguments) async throws -> String {
        await toolbox.saldoDeLista(name: arguments.name)
    }
}

/// Sin argumentos: la deuda con los bancos es de hoy.
@Generable
struct NoArguments: Sendable {
    @Guide(description: "No se usa. Déjalo vacío.")
    var unused: String
}

struct DeudaPorTarjetaTool: Tool {
    let toolbox: LedgerToolbox

    let name = "deudaPorTarjeta"
    let description = """
    Cuánto se debe hoy en cada tarjeta de crédito: lo ya facturado y pendiente, \
    y lo acumulado en el ciclo abierto. Úsala cuando pregunten cuánto deben al \
    banco. Esta deuda es con el banco y nunca se suma con la que hay entre \
    personas.
    """

    func call(arguments _: NoArguments) async throws -> String {
        await toolbox.deudaPorTarjeta()
    }
}

struct DisponibleProyectadoTool: Tool {
    let toolbox: LedgerToolbox

    let name = "disponibleProyectado"
    let description = """
    Cuánto queda del periodo de pago vigente: lo que entró menos lo que se \
    gastó desde el último sueldo, menos los pagos con fecha que faltan. Úsala \
    cuando pregunten cuánto les queda, cuánto pueden gastar, o si les alcanza. \
    La respuesta ya viene con la aclaración de que sale de lo registrado y no \
    del banco: cópiala tal cual, no la quites.
    """

    func call(arguments _: NoArguments) async throws -> String {
        await toolbox.disponibleProyectado()
    }
}

struct OrigenDelIngresoTool: Tool {
    let toolbox: LedgerToolbox

    let name = "origenDelIngreso"
    let description = """
    De dónde vino el dinero en un mes, por categoría (sueldo, freelance, \
    venta…). Úsala cuando pregunten qué les entró o de dónde salió su dinero. \
    No la uses para gastos: para eso está totalPorCategoria, y las dos listas \
    no se mezclan.
    """

    func call(arguments: MonthArguments) async throws -> String {
        await toolbox.origenDelIngreso(year: arguments.year, month: arguments.month)
    }
}

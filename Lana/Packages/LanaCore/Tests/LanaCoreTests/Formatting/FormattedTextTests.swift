import Foundation
import Testing
@testable import LanaCore

/// Cómo se escriben los montos y las fechas, con **igualdad exacta**.
///
/// La app declara español (ADR-0047), pero eso no basta: lo que protege este
/// archivo es que el formato no vuelva a seguir al dispositivo. Antes de
/// ADR-0047, `Money.formatted()` daba "MX$1,234.50" con región distinta de
/// México, y las fechas salían "September 2026" en cualquier teléfono.
@Suite("Formato visible, con locale fijo")
struct FormattedTextTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    @Test("Un monto se escribe igual sin importar la región del teléfono")
    func elMontoNoSigueAlDispositivo() {
        let money = Money(amount: Decimal(string: "1234.5") ?? 0, currency: .mxn)

        #expect(money.formatted() == "$1,234.50")
    }

    @Test("El mes y el año van en español, con inicial mayúscula")
    func mesYAnioEnEspanol() throws {
        #expect(try LanaDateFormat.monthYear(date(2026, 9, 15), calendar: calendar) == "Septiembre 2026")
    }

    @Test("Una fecha de fila lleva día, mes abreviado y año")
    func fechaDeFila() throws {
        #expect(try LanaDateFormat.shortDate(date(2026, 9, 15), calendar: calendar) == "15 sep 2026")
    }

    @Test("Fecha con hora: la fecha en español y la hora al minuto")
    func fechaConHora() throws {
        let text = try LanaDateFormat.shortDateTime(date(2026, 9, 15), calendar: calendar)

        // La fecha se fija entera; la hora solo se comprueba que esté. El
        // separador que ICU mete antes de "p.m." es un espacio angosto que no
        // se ve al leer el código, y fijarlo sería apostar a un carácter
        // invisible. Lo que estaba roto era la fecha.
        #expect(text.hasPrefix("15 sep 2026, "))
        #expect(text.contains("12:00"))
    }
}

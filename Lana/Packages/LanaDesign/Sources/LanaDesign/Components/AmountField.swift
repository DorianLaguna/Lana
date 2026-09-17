import SwiftUI

/// El campo donde se teclea un monto. Alineado a la derecha y **vacío cuando
/// el monto es cero**: con `TextField(value:format:)` el campo mostraba un
/// "0" y el cursor caía a su izquierda, así que los dígitos entraban antes
/// del cero y había que mover el cursor a mano para escribir del lado
/// correcto (ADR-0056).
///
/// Acepta dígitos y un separador decimal —punto o coma, lo que dé el teclado—
/// e ignora lo demás, así que nunca hay un texto que no sea un monto.
public struct AmountField: View {
    @Environment(\.lana) private var lana

    @Binding private var amount: Decimal
    @State private var text: String
    private let style: LanaTextStyle

    /// - Parameters:
    ///   - amount: el monto que se edita. Cero se muestra como campo vacío.
    ///   - style: `.draftAmount` en una tarjeta de borrador, `.rowTitle` en
    ///     una fila de formulario.
    public init(amount: Binding<Decimal>, style: LanaTextStyle = .draftAmount) {
        _amount = amount
        _text = State(initialValue: amountText(amount.wrappedValue))
        self.style = style
    }

    public var body: some View {
        TextField("0", text: $text)
            .lanaFont(style)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
        #if os(iOS)
            .keyboardType(.decimalPad)
        #endif
            .onChange(of: text) { _, newText in
                let sanitized = sanitizedAmountInput(newText)
                if sanitized.text != newText {
                    text = sanitized.text
                }
                amount = sanitized.amount
            }
            // El monto también cambia desde fuera ("Pagar todo" precarga el
            // corte, el parser corrige el borrador): el texto lo sigue.
            .onChange(of: amount) { _, newAmount in
                if sanitizedAmountInput(text).amount != newAmount {
                    text = amountText(newAmount)
                }
            }
    }
}

/// Cómo se escribe un monto dentro del campo: sin separador de miles y con
/// punto decimal. Cero es cadena vacía — el campo enseña su "0" de marca de
/// agua en vez de un cero que estorba al teclear.
func amountText(_ amount: Decimal) -> String {
    amount == 0 ? "" : "\(amount)"
}

/// Deja solo dígitos y un separador decimal, y regresa el monto que
/// representan.
///
/// La coma es decimal o de miles según el resto del texto: con un punto
/// presente ("1,250.50") son miles y se tiran; sin él ("12,5") es el decimal,
/// que es lo que da el teclado numérico en las regiones que lo usan.
func sanitizedAmountInput(_ input: String) -> (text: String, amount: Decimal) {
    let separators: Set<Character> = input.contains(".") ? ["."] : [","]
    var digits = ""
    var hasSeparator = false
    for character in input {
        if character.isNumber {
            digits.append(character)
        } else if separators.contains(character), !hasSeparator, !digits.isEmpty {
            digits.append(".")
            hasSeparator = true
        }
    }
    guard !digits.isEmpty else { return ("", 0) }
    // "12." todavía no es un número, pero es un texto válido a medio teclear.
    let amount = Decimal(string: digits) ?? Decimal(string: String(digits.dropLast())) ?? 0
    return (digits, amount)
}

#Preview {
    @Previewable @State var amount = Decimal(0)
    @Previewable @State var other = Decimal(string: "1250.5") ?? 0
    return VStack(alignment: .trailing, spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases.prefix(2)) { theme in
            LanaCard {
                VStack(alignment: .trailing, spacing: Space.md.rawValue) {
                    AmountField(amount: $amount)
                    AmountField(amount: $other, style: .rowTitle)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .lanaTheme(theme)
        }
    }
    .padding(LanaMetrics.screenMargin)
}

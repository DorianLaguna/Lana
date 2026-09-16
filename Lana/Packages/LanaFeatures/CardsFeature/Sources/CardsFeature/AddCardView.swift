import LanaCore
import LanaDesign
import SwiftUI

/// El alta y la edición de una tarjeta (rediseño, sección 04).
///
/// Pide alias, tipo, últimos cuatro, nombre en Wallet, color y —solo para
/// crédito— límite, corte y día límite de pago. **Nunca** el número completo,
/// el CVV ni el vencimiento, y lo dice en la propia pantalla.
public struct AddCardView: View {
    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    @Bindable private var model: AddCardModel
    private let onDone: () -> Void

    public init(model: AddCardModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.p18.rawValue) {
                    kindChips
                    identityCard
                    colorCard

                    // El débito no tiene línea de crédito, corte ni fecha
                    // límite en la realidad: solo se pregunta para crédito.
                    if model.kind == .credit {
                        creditCard
                    }

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .lanaFont(.rowSubtitle)
                            .foregroundStyle(lana.attention)
                    }

                    Text("Lana nunca guarda el número completo, el CVV ni la fecha de vencimiento.")
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink42)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.p18.rawValue)
                .padding(.bottom, Space.p40.rawValue)
            }
            .background(lana.bg)
            .navigationTitle("Tarjeta")
            .lanaInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await model.save() {
                                onDone()
                            }
                        }
                    } label: {
                        if model.isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar")
                        }
                    }
                    .disabled(model.isSaving)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var kindChips: some View {
        FlowLayout {
            Chip("Crédito", tone: model.kind == .credit ? .neutral : .suggestion) { model.kind = .credit }
            Chip("Débito", tone: model.kind == .debit ? .neutral : .suggestion) { model.kind = .debit }
        }
        .accessibilityLabel("Tipo: \(model.kind == .credit ? "crédito" : "débito")")
    }

    private var identityCard: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                field("Alias", placeholder: "Bancomer", text: $model.alias)
                field("Últimos 4 dígitos", placeholder: "Opcional", text: $model.lastFourDigits, isNumeric: true)
                field("Nombre en Wallet", placeholder: "Opcional", text: $model.walletMatchHint)
                Text("""
                El nombre en Wallet solo sirve para reconocer esta tarjeta en las automatizaciones de \
                Apple Pay, si Wallet le dice distinto que el alias.
                """)
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Color plano elegido por la persona, no el logo del banco: Lana no usa
    /// marcas de bancos (rediseño, sección "Assets").
    private var colorCard: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                Text("Color")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                HStack(spacing: Space.p9.rawValue) {
                    ForEach(LanaCardColors.palette, id: \.self) { hex in
                        Button {
                            model.colorHex = hex
                        } label: {
                            RoundedRectangle(cornerRadius: Radius.swatch.rawValue, style: .continuous)
                                .fill(Color(hex: hex) ?? lana.accentFill)
                                .frame(width: LanaMetrics.cardSwatchWidth, height: LanaMetrics.cardSwatchHeight)
                                .overlay {
                                    if model.colorHex == hex {
                                        RoundedRectangle(cornerRadius: Radius.swatch.rawValue, style: .continuous)
                                            .strokeBorder(lana.ink, lineWidth: LanaMetrics.outline)
                                    }
                                }
                                .frame(height: LanaMetrics.minTouchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(hex)")
                        .accessibilityAddTraits(model.colorHex == hex ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
        }
    }

    private var creditCard: some View {
        LanaCard {
            VStack(alignment: .leading, spacing: Space.p12.rawValue) {
                amountField("Límite", value: $model.limitAmount)
                dayField("Día de corte", value: $model.cutoffDay)
                dayField("Día límite de pago", value: $model.dueDay)

                // Un recurrente del 31 cae el último día en los meses que no lo
                // tienen; lo mismo aplica al corte y al pago.
                Text("Si el mes no tiene ese día, cae en el último.")
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink42)
            }
        }
    }

    private func field(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        isNumeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            Text(label)
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink50)
            TextField(placeholder, text: text)
                .lanaFont(.rowTitle)
                .foregroundStyle(lana.ink)
            #if os(iOS)
                .keyboardType(isNumeric ? .numberPad : .default)
            #endif
            HairlineDivider()
        }
    }

    /// El límite es `Decimal` y los días son `Int`: `TextField(value:format:)`
    /// necesita el tipo concreto, no un genérico sobre `Numeric`.
    private func amountField(_ label: String, value: Binding<Decimal>) -> some View {
        numberRow(label) {
            TextField("0", value: value, format: .number)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
        }
    }

    private func dayField(_ label: String, value: Binding<Int>) -> some View {
        numberRow(label) {
            TextField("1-31", value: value, format: .number)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
        }
    }

    private func numberRow(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
            HStack {
                Text(label)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.ink50)
                Spacer(minLength: Space.sm.rawValue)
                field()
                    .lanaFont(.rowTitle)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(lana.ink)
            }
            HairlineDivider()
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        AddCardView(model: AddCardModel(cardStore: InMemoryCardStore()), onDone: {})
            .lanaTheme(theme)
    }
}

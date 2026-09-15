import LanaCore
import LanaDesign
import SwiftUI

/// La pestaña Tarjetas: lista, alta y detalle (Fase 6.5, calca
/// `Tarjetas.dc.html`). Sin lógica propia — refleja `CardsModel`
/// (Docs/ARCHITECTURE.md).
public struct CardsView: View {
    @Environment(\.lana) private var lana
    private let model: CardsModel
    /// Un solo estado para alta y edición — `AddCardModel` ya sabe cuál es
    /// según se haya creado con `editing: nil` o con una tarjeta.
    @State private var addCardModel: AddCardModel?
    /// `CardsFeature` no puede construir un editor de gasto — eso vive en
    /// `DashboardFeature`, y las features no se importan entre sí — así
    /// que la app (`ContentView`, que sí importa ambas) decide qué hacer
    /// cuando se toca un gasto dentro del detalle de una tarjeta.
    private let onExpenseTap: (Expense) -> Void
    /// Reabre la guía de configuración de Apple Pay como hoja (R1.4). Es la
    /// captura automática de gastos vía Atajos, no un método de pago, así
    /// que su hogar es Tarjetas —donde el usuario ya piensa en sus
    /// tarjetas— y no Ajustes. `CardsFeature` no puede construir
    /// `GuiaApplePayView` (vive en `OnboardingFeature`, y las features no se
    /// importan entre sí), así que solo dispara este handler; el target de
    /// la app arma y presenta la hoja.
    ///
    /// La app SIEMPRE lo cablea, aunque el dispositivo no pueda armar la
    /// automatización: quien explica esa incompatibilidad es la propia guía,
    /// con su pantalla de "No se puede crear la automatización" (R2.6), y
    /// esconder la entrada dejaría al usuario sin saber por qué. `nil` solo
    /// en previews; sin él, la fila no se muestra.
    private let onConfigureApplePay: (() -> Void)?

    public init(
        model: CardsModel,
        onExpenseTap: @escaping (Expense) -> Void,
        onConfigureApplePay: (() -> Void)? = nil) {
        self.model = model
        self.onExpenseTap = onExpenseTap
        self.onConfigureApplePay = onConfigureApplePay
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.cards.isEmpty, !model.isLoading {
                    EmptyStateView(
                        systemImage: "creditcard",
                        title: "Sin tarjetas",
                        // La guía de Apple Pay solo aparece con al menos una
                        // tarjeta —el emparejamiento la necesita—, así que
                        // aquí se dice, en vez de que desaparezca sin razón.
                        message: """
                        Agrega una para ver sus gastos, su deuda y poder configurar la \
                        captura automática de Apple Pay.
                        """,
                        actionTitle: "Agregar tarjeta",
                        action: { addCardModel = model.makeAddCardModel() })
                } else {
                    ScrollView {
                        VStack(spacing: Space.sm.rawValue) {
                            ForEach(model.cards) { card in
                                NavigationLink(value: card.id) {
                                    CardRow(card: card, debt: model.debt(for: card))
                                }
                                .buttonStyle(.plain)
                            }

                            if let onConfigureApplePay {
                                applePaySection(onConfigureApplePay)
                                    .padding(.top, Space.md.rawValue)
                            }
                        }
                        .padding(Space.md.rawValue)
                        // El micrófono flotante de `MainTabView` caía justo
                        // encima de la entrada de Apple Pay, que es el último
                        // elemento de esta lista.
                        .floatingMicClearance()
                    }
                }
            }
            .background(lana.surface)
            .navigationTitle("Tarjetas")
            // Por `CardID`, no por `Card`: así, cuando `model.cards` se
            // refresca tras editar, este destino se recalcula con la
            // versión viva de la tarjeta en vez de quedarse con la que
            // estaba al momento de navegar.
            .navigationDestination(for: CardID.self) { cardID in
                if let card = model.cards.first(where: { $0.id == cardID }) {
                    CardDetailView(
                        model: model.makeCardDetailModel(for: card),
                        onEdit: { addCardModel = model.makeAddCardModel(editing: card) },
                        onExpenseTap: onExpenseTap)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addCardModel = model.makeAddCardModel()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $addCardModel) { addCardModel in
                AddCardView(model: addCardModel, onDone: {
                    self.addCardModel = nil
                    // `AddCardModel.save()` escribe directo en `cardStore`,
                    // no pasa por `CardsModel.save()` — sin este refresco la
                    // lista se queda con los datos viejos hasta que la vista
                    // vuelva a aparecer (cambiar de tab), y parece que no
                    // guardó.
                    Task { await model.onAppear() }
                })
            }
        }
        .task { await model.onAppear() }
        .refreshable { await model.onAppear() }
    }

    /// La entrada a la guía de Apple Pay (R1.4), en el volumen que le toca.
    ///
    /// La primera vez es una invitación: hay algo que el usuario todavía no
    /// sabe que puede hacer, y va en el par de acento del tema. Una vez que
    /// recorrió la guía deja de ser noticia y se vuelve una fila más, bajo su
    /// encabezado — un degradado permanente competiría para siempre con la
    /// lista de tarjetas, que es lo que el usuario viene a ver.
    @ViewBuilder
    private func applePaySection(_ action: @escaping () -> Void) -> some View {
        if model.hasSeenApplePayGuide {
            VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                Text("AUTOMATIZACIÓN")
                    .lanaFont(.caption)
                    .foregroundStyle(lana.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                seenApplePayRow(action)
            }
        } else {
            configureApplePayRow(action)
        }
    }

    /// La entrada ya recorrida. Nunca dice "activado" ni lleva palomita: Lana
    /// no puede comprobar que la automatización exista —eso mismo le dice la
    /// pantalla de cierre de la guía— y una señal de "listo" aquí la
    /// contradiría.
    private func seenApplePayRow(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LanaCard {
                HStack(spacing: Space.sm.rawValue) {
                    Image(systemName: "creditcard.and.123")
                        .foregroundStyle(lana.accent)
                        .frame(width: Space.lg.rawValue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Guía de Apple Pay")
                            .lanaFont(.body)
                            .foregroundStyle(lana.textPrimary)
                        Text("Vuelve a verla cuando quieras")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    }

                    Spacer(minLength: Space.sm.rawValue)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(lana.textSecondary.opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// La invitación de la primera vez: fila etiquetada y seleccionable, cuyo
    /// toque solo delega en el handler inyectado. Distintiva a propósito, no
    /// una tarjeta gris más — es la acción de "inteligencia/automatización",
    /// el mismo mundo que Lana y el micrófono flotante, así que usa el par de
    /// acento del tema (accent → highlight), el lenguaje visual que la app
    /// reserva para eso. Icono en círculo de acento y texto blanco encima del
    /// degradado para que resalte entre las tarjetas.
    private func configureApplePayRow(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.md.rawValue) {
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Configurar Apple Pay")
                        .lanaFont(.headline)
                        .foregroundStyle(.white)
                    Text("Registra tus compras automáticamente")
                        .lanaFont(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer(minLength: Space.sm.rawValue)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(Space.md.rawValue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [lana.accent, lana.highlight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Space.sm.rawValue, style: .continuous))
            .shadow(color: lana.accent.opacity(0.3), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct CardRow: View {
    @Environment(\.lana) private var lana
    let card: Card
    let debt: Money?

    var body: some View {
        LanaCard {
            HStack(spacing: Space.sm.rawValue) {
                RoundedRectangle(cornerRadius: Space.xs.rawValue, style: .continuous)
                    .fill((Color(hex: card.colorHex) ?? lana.accent).gradient)
                    .frame(width: 52, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.alias)
                        .lanaFont(.body)
                        .foregroundStyle(lana.textPrimary)
                    if let lastFourDigits = card.lastFourDigits {
                        Text("•••• \(lastFourDigits)")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let debt, debt.amount > 0 {
                        Text(debt.formatted())
                            .lanaFont(.body)
                            .monospacedDigit()
                            .foregroundStyle(lana.textPrimary)
                        Text("debes")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    } else {
                        Text("Sin deuda")
                            .lanaFont(.caption)
                            .foregroundStyle(lana.textSecondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(lana.textSecondary.opacity(0.6))
            }
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        CardsView(
            model: CardsModel(
                cardStore: InMemoryCardStore(),
                store: InMemoryExpenseStore(),
                cardPaymentStore: InMemoryCardPaymentStore()),
            onExpenseTap: { _ in },
            onConfigureApplePay: {})
            .lanaTheme(theme)
    }
}

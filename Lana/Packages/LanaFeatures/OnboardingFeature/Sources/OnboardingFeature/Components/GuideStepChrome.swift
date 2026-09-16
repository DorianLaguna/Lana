import LanaDesign
import SwiftUI

/// El marco de un paso de la guía de Apple Pay (rediseño, sección 13): la
/// barra de progreso, "Omitir", el número de paso y el título.
///
/// Un segmento por pantalla de `GuiaApplePayModel`: antes de empezar, conectar
/// Wallet, armar la automatización, qué esperar y el repaso. El repaso es un
/// paso propio porque lleva lo único que se puede comprobar ("¿Cómo saber si
/// quedó bien?"); fundido con "Qué esperar" nunca llegaba a verse.
struct GuideStepChrome<Content: View>: View {
    @Environment(\.lana) private var lana

    /// Cuál paso se está viendo, empezando en 1.
    let step: Int
    /// Cuántos pasos tiene la guía.
    let totalSteps: Int
    let title: String
    /// El párrafo bajo el título; `nil` en los pasos que abren con contenido.
    /// No se llama `body`: chocaría con el de la propia vista.
    let message: String?
    let onSkip: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            progress
                .padding(.bottom, Space.p14.rawValue)

            Text("Paso \(step) de \(totalSteps)")
                .lanaFont(.minorHeader)
                .foregroundStyle(lana.accent)
                .padding(.bottom, Space.p14.rawValue)

            Text(title)
                .lanaFont(.guideTitle)
                .foregroundStyle(lana.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Space.p14.rawValue)

            if let message {
                Text(message)
                    .lanaFont(.explanation)
                    .foregroundStyle(lana.ink60)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.p34.rawValue)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// La guía **siempre** se puede omitir (R1.3): nadie queda atrapado en una
    /// configuración que decidió no hacer.
    private var progress: some View {
        HStack(spacing: Space.p10.rawValue) {
            HStack(spacing: Space.p5.rawValue) {
                ForEach(1 ... totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? lana.accentFill : lana.surface3)
                        .frame(height: LanaMetrics.guideProgressHeight)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Paso \(step) de \(totalSteps)")

            Button("Omitir", action: onSkip)
                .lanaFont(.callout)
                .foregroundStyle(lana.ink50)
                .buttonStyle(.plain)
                .frame(minHeight: LanaMetrics.minTouchTarget)
        }
    }
}

/// Una fila del mapeo Wallet → Lana (rediseño, sección 13, paso 2): el campo
/// que da Atajos, una flecha, y el campo que Lana espera.
///
/// Es la parte donde más gente se atora, así que se ve como lo que es —una
/// correspondencia— en vez de describirse en prosa.
struct MappingRow: View {
    @Environment(\.lana) private var lana

    let walletLabel: String
    let lanaLabel: String

    var body: some View {
        LanaCard(padding: .p15) {
            HStack(spacing: Space.p12.rawValue) {
                field("Wallet", value: walletLabel, alignment: .leading)

                Image(systemName: "arrow.right")
                    .lanaFont(.rowSubtitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(lana.accent)
                    .frame(width: LanaMetrics.mappingArrowWidth)
                    .accessibilityHidden(true)

                field("Lana", value: lanaLabel, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wallet \(walletLabel) va en Lana \(lanaLabel)")
    }

    private func field(_ source: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Space.xs.rawValue) {
            Text(source)
                .lanaFont(.minorHeader)
                .foregroundStyle(lana.ink42)
            Text(value)
                .lanaFont(.bodyEmphasis)
                .foregroundStyle(lana.ink)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

/// Un aviso con icono sobre `attentionSofter`: algo que conviene saber y que
/// no es un requisito ni un paso — el fondo es lo que lo separa de ellos.
struct GuideNotice: View {
    @Environment(\.lana) private var lana

    let systemImage: String
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.p10.rawValue) {
            Image(systemName: systemImage)
                .lanaFont(.bodyEmphasis)
                .foregroundStyle(lana.attention)
                .accessibilityHidden(true)
            Text(message)
                .lanaFont(.detail)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md.rawValue)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            lana.attentionSofter,
            in: RoundedRectangle(cornerRadius: Radius.card.rawValue, style: .continuous))
    }
}

/// Un número de paso en un círculo: la numeración se ve, no depende solo del
/// orden visual.
struct GuideStepNumber: View {
    @Environment(\.lana) private var lana

    let number: Int

    var body: some View {
        Text("\(number)")
            .lanaFont(.footnote)
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(lana.accent)
            .frame(width: LanaMetrics.badge, height: LanaMetrics.badge)
            .background(lana.accentSoft, in: Circle())
    }
}

/// La advertencia del paso 2: qué **no** hace la captura automática, dicho
/// antes de configurarla y no después.
struct GuideWarning: View {
    @Environment(\.lana) private var lana

    let text: String
    /// La parte que no puede pasarse por alto — va en tinta plena.
    let emphasis: String?

    var body: some View {
        LanaCard(fill: .attention) {
            message
                .lanaFont(.detail)
                .foregroundStyle(lana.ink70)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var message: Text {
        guard let emphasis else { return Text(text) }
        let strong = Text(emphasis)
            .foregroundStyle(lana.ink)
            .fontWeight(.semibold)
        return Text("\(text) \(strong)")
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.lg.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                GuideStepChrome(
                    step: 2,
                    totalSteps: 5,
                    title: "Conecta Wallet con tus tarjetas",
                    message: "En la app Atajos vas a crear una automatización. Lana necesita tres campos:",
                    onSkip: {},
                    content: {
                        VStack(spacing: Space.p10.rawValue) {
                            MappingRow(walletLabel: "Monto", lanaLabel: "Monto")
                            MappingRow(walletLabel: "Comercio", lanaLabel: "Concepto")
                            GuideWarning(
                                text: "Funciona solo con pagos por contacto y todo lo capturado queda",
                                emphasis: "por revisar.")
                        }
                    })
                    .padding(LanaMetrics.onboardingMargin)
                    .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                    .lanaTheme(theme)
            }
        }
    }
}

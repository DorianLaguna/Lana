import SwiftUI

/// Una barra de progreso en cápsula sobre una pista `surface2`: la de "Te
/// queda", la de Gastado/Ingresos, el límite de una tarjeta, cada categoría.
public struct ProgressTrack: View {
    /// Con qué se rellena la barra.
    public enum Fill: Sendable, Equatable {
        /// El relleno del acento: lo neutro que se puede tocar.
        case accent
        /// Lo que domina o reclama acción.
        case attention
        /// Lo que está bien.
        case positive
        /// `accentFill → highlight`, de izquierda a derecha (Gastado/Ingresos).
        case accentGradient
    }

    @Environment(\.lana) private var lana

    private let fraction: Double
    private let height: CGFloat
    private let fill: Fill

    /// - Parameters:
    ///   - fraction: 0...1; lo que se salga del rango se recorta.
    ///   - height: uno de los grosores de `LanaMetrics` (`barRegular`, `barMedium`…).
    public init(fraction: Double, height: CGFloat = LanaMetrics.barMedium, fill: Fill = .accent) {
        self.fraction = min(max(fraction, 0), 1)
        self.height = height
        self.fill = fill
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(lana.surface2)
                Capsule()
                    .fill(fillStyle)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }

    private var fillStyle: AnyShapeStyle {
        switch fill {
        case .accent:
            AnyShapeStyle(lana.accentFill)
        case .attention:
            AnyShapeStyle(lana.attention)
        case .positive:
            AnyShapeStyle(lana.positive)
        case .accentGradient:
            AnyShapeStyle(LinearGradient(
                colors: [lana.accentFill, lana.highlight],
                startPoint: .leading,
                endPoint: .trailing))
        }
    }
}

/// Una lista de montos con barras proporcionales, ordenada de mayor a menor:
/// "En qué se fue", "En qué usas esta tarjeta".
///
/// La primera barra va en `attention` y al 100 %; las demás en el acento, con
/// ancho proporcional a la primera. El color marca qué domina, no qué es.
public struct RankedBarList: View {
    /// Una fila de la lista.
    public struct Item: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let amountText: String
        public let value: Double

        /// - Parameter value: la magnitud para la proporción de la barra; no se
        ///   muestra (el texto va en `amountText`).
        public init(id: String, title: String, amountText: String, value: Double) {
            self.id = id
            self.title = title
            self.amountText = amountText
            self.value = value
        }
    }

    @Environment(\.lana) private var lana

    private let items: [Item]
    private let barHeight: CGFloat
    private let itemSpacing: Space
    private let onSelect: ((Item) -> Void)?

    /// - Parameters:
    ///   - items: ya ordenados de mayor a menor.
    ///   - barHeight: `LanaMetrics.barRegular` en Mes, `LanaMetrics.barThin` en una tarjeta.
    ///   - itemSpacing: `.p18` en Mes, `.p14` en una tarjeta.
    public init(
        items: [Item],
        barHeight: CGFloat = LanaMetrics.barRegular,
        itemSpacing: Space = .p18,
        onSelect: ((Item) -> Void)? = nil) {
        self.items = items
        self.barHeight = barHeight
        self.itemSpacing = itemSpacing
        self.onSelect = onSelect
    }

    public var body: some View {
        let maxValue = items.map(\.value).max() ?? 0
        VStack(alignment: .leading, spacing: itemSpacing.rawValue) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    onSelect?(item)
                } label: {
                    VStack(alignment: .leading, spacing: Space.p7.rawValue) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.title)
                                .lanaFont(.rowTitle)
                                .foregroundStyle(lana.ink)
                            Spacer(minLength: Space.sm.rawValue)
                            Text(item.amountText)
                                .lanaFont(.rowTitle)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(lana.ink)
                        }
                        ProgressTrack(
                            fraction: maxValue > 0 ? item.value / maxValue : 0,
                            height: barHeight,
                            fill: index == 0 ? .attention : .accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onSelect == nil)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.xl.rawValue) {
            ForEach(LanaTheme.allCases) { theme in
                VStack(alignment: .leading, spacing: Space.p20.rawValue) {
                    ProgressTrack(fraction: 0.79)
                    ProgressTrack(fraction: 0.79, height: LanaMetrics.barThick, fill: .accentGradient)
                    RankedBarList(items: [
                        .init(id: "a", title: "Despensa", amountText: "$3,120", value: 3120),
                        .init(id: "b", title: "Transporte", amountText: "$1,840", value: 1840),
                        .init(id: "c", title: "Comida fuera", amountText: "$960", value: 960)
                    ])
                }
                .padding(LanaMetrics.screenMargin)
                .background(LanaColors(theme: theme, colorScheme: .dark).bg)
                .lanaTheme(theme)
            }
        }
    }
}

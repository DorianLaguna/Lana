//
//  LanaTabBar.swift
//  Lana
//

import LanaDesign
import SwiftUI

/// Las cuatro pestañas del rediseño (sección 01). Ajustes ya no es pestaña:
/// se empuja desde el avatar de Hoy.
enum MainTab: String, CaseIterable {
    case hoy
    case mes
    case tarjetas
    case gente

    var title: String {
        switch self {
        case .hoy: "Hoy"
        case .mes: "Mes"
        case .tarjetas: "Tarjetas"
        case .gente: "Gente"
        }
    }

    var systemImage: String {
        switch self {
        case .hoy: "house"
        case .mes: "chart.bar"
        case .tarjetas: "creditcard"
        case .gente: "person.2"
        }
    }
}

/// La barra flotante: Hoy · Mes · [micrófono] · Tarjetas · Gente.
///
/// El micrófono vive **dentro** de la barra, en su ranura central: sigue
/// siendo lo más visible de la pantalla pero ya no sobresale ni tapa filas ni
/// montos, que era el bug del micrófono flotante. Las pantallas dejan su
/// colchón con `tabBarClearance()`.
struct LanaTabBar: View {
    @Environment(\.lana) private var lana
    @Binding var selection: MainTab
    /// Alimenta el punto de la pestaña Hoy.
    let pendingReviewCount: Int
    let onMic: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.hoy)
            item(.mes)
            micButton
            item(.tarjetas)
            item(.gente)
        }
        .frame(height: LanaMetrics.tabBarHeight)
        .background {
            RoundedRectangle(cornerRadius: Radius.tabBar.rawValue, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tabBar.rawValue, style: .continuous)
                        .fill(lana.tabBarTint))
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tabBar.rawValue, style: .continuous)
                .strokeBorder(lana.tabBarBorder, lineWidth: LanaMetrics.hairline))
    }

    private func item(_ tab: MainTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: Space.xs.rawValue) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: LanaMetrics.tabIcon))
                    .frame(height: LanaMetrics.tabIcon)
                    .overlay(alignment: .topTrailing) {
                        if tab == .hoy, pendingReviewCount > 0 {
                            Circle()
                                .fill(lana.attention)
                                .frame(width: LanaMetrics.dot, height: LanaMetrics.dot)
                                .offset(x: Space.xs.rawValue, y: -Space.p2.rawValue)
                        }
                    }
                Text(tab.title)
                    .lanaFont(.tabLabel)
            }
            .foregroundStyle(isSelected ? lana.accent : lana.ink42)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: tab))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityLabel(for tab: MainTab) -> String {
        guard tab == .hoy, pendingReviewCount > 0 else { return tab.title }
        return "\(tab.title), \(pendingReviewCount) por revisar"
    }

    private var micButton: some View {
        Button(action: onMic) {
            Image(systemName: "mic.fill")
                .font(.system(size: LanaMetrics.tabIcon, weight: .semibold))
                .foregroundStyle(lana.onAccent)
                .frame(width: LanaMetrics.micDiameter, height: LanaMetrics.micDiameter)
                .background(lana.accentFill, in: Circle())
                .shadow(color: lana.accentShadow, radius: Space.p9.rawValue, y: Space.p6.rawValue)
        }
        .buttonStyle(.plain)
        .frame(width: LanaMetrics.micSlot)
        .accessibilityLabel("Dictar un movimiento")
    }
}

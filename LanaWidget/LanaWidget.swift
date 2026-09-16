//
//  LanaWidget.swift
//  LanaWidget
//

import LanaDesign
import SwiftUI
import WidgetKit

/// Sin datos vivos que mostrar — una sola entrada estática alcanza
/// (ADR-0018). Si algún día el widget necesita contenido dinámico, este
/// `Provider` hay que revisarlo desde cero, no extenderlo.
struct CaptureEntry: TimelineEntry {
    let date: Date
}

struct CaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaptureEntry {
        CaptureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (CaptureEntry) -> Void) {
        completion(CaptureEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaptureEntry>) -> Void) {
        completion(Timeline(entries: [CaptureEntry(date: Date())], policy: .never))
    }
}

/// El botón de captura rápida: tocarlo abre Lana directo en modo escucha
/// (ADR-0018), vía `lana://capture`.
struct LanaCaptureWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Link(destination: captureURL) {
            Image(systemName: "mic.fill")
                .font(.system(size: LanaMetrics.stopGlyph * 1.3, weight: .semibold))
                .foregroundStyle(LanaColors(theme: .cobalto, colorScheme: colorScheme).onAccent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("Dictar un movimiento")
    }

    private var captureURL: URL {
        guard let url = URL(string: "lana://capture") else {
            preconditionFailure("lana://capture es un literal fijo, siempre válido")
        }
        return url
    }
}

/// El fondo va por separado porque `.containerBackground` lo pinta hasta el
/// borde del widget (a diferencia del contenido, que WidgetKit margina por
/// default desde iOS 17) — necesita su propio `@Environment` porque se monta
/// en un punto distinto del árbol al de `LanaCaptureWidgetView`. Sin App
/// Group, el widget no lee nada del store, así que no puede saber qué tema
/// eligió el usuario en Ajustes; usa el tema Cobalto por default, adaptado
/// a claro/oscuro del sistema nada más.
private struct LanaCaptureWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    private var lana: LanaColors {
        LanaColors(theme: .cobalto, colorScheme: colorScheme)
    }

    /// El micrófono sobre el color del tema, plano — como en la barra de la app.
    var body: some View {
        lana.accentFill
    }
}

struct LanaCaptureWidget: Widget {
    let kind = "LanaCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaptureProvider()) { _ in
            LanaCaptureWidgetView()
                .containerBackground(for: .widget) { LanaCaptureWidgetBackground() }
        }
        .configurationDisplayName("Registrar gasto")
        .description("Toca para abrir Lana y dictar un gasto de inmediato.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    LanaCaptureWidget()
} timeline: {
    CaptureEntry(date: .now)
}

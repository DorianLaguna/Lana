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
/// (ADR-0018), vía `lana://capture`. Vive en la pantalla de inicio como
/// mosaico chico y en la pantalla bloqueada como círculo bajo el reloj
/// (ADR-0057) — el mismo destino, dos tamaños.
///
/// El toque va con `.widgetURL` y no con `Link` porque en un widget chico
/// (y en uno accesorio) el sistema solo respeta el primero: toda la
/// superficie es un solo destino.
struct LanaCaptureWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family

    var body: some View {
        glyph
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(LanaCaptureLink.url)
            .accessibilityLabel("Dictar un movimiento")
    }

    /// En la pantalla bloqueada el sistema pinta el widget en su propio modo
    /// desteñido y lo encierra en un círculo chico: ni el acento del tema
    /// sobreviviría ahí, ni cabe el glifo del mosaico. Se deja que combine con
    /// el reloj y sus vecinos, que es lo que el usuario espera de esa fila.
    @ViewBuilder
    private var glyph: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: LanaMetrics.stopGlyph, weight: .semibold))
        default:
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: LanaMetrics.stopGlyph * 1.3, weight: .semibold))
                .foregroundStyle(LanaColors(theme: .cobalto, colorScheme: colorScheme).onAccent)
        }
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
    @Environment(\.widgetFamily) private var family

    private var lana: LanaColors {
        LanaColors(theme: .cobalto, colorScheme: colorScheme)
    }

    /// La moneda sobre el color del tema, plana — el mismo acento que la
    /// barra de la app. En la pantalla bloqueada, en cambio, el fondo es el
    /// del sistema: el mismo disco translúcido del clima y la batería.
    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryWidgetBackground()
        default:
            lana.accentFill
        }
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
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    LanaCaptureWidget()
} timeline: {
    CaptureEntry(date: .now)
}

#Preview(as: .accessoryCircular) {
    LanaCaptureWidget()
} timeline: {
    CaptureEntry(date: .now)
}

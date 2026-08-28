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
/// (ADR-0018), vía `lana://capture`. Sin App Group — el widget no lee
/// nada del store, así que no puede saber qué tema eligió el usuario en
/// Ajustes; usa el tema Cobalto por default, adaptado a claro/oscuro del
/// sistema nada más.
struct LanaCaptureWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var lana: LanaColors {
        LanaColors(theme: .cobalto, colorScheme: colorScheme)
    }

    var body: some View {
        Link(destination: captureURL) {
            ZStack {
                LinearGradient(
                    colors: [lana.accent, lana.highlight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var captureURL: URL {
        guard let url = URL(string: "lana://capture") else {
            preconditionFailure("lana://capture es un literal fijo, siempre válido")
        }
        return url
    }
}

struct LanaCaptureWidget: Widget {
    let kind = "LanaCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaptureProvider()) { _ in
            LanaCaptureWidgetView()
                .containerBackground(for: .widget) { Color.clear }
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

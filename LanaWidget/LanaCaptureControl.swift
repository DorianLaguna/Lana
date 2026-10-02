//
//  LanaCaptureControl.swift
//  LanaWidget
//

import AppIntents
import SwiftUI
import WidgetKit

/// Abre Lana en modo escucha. Existe solo porque la acción de un
/// `ControlWidgetButton` tiene que ser un `AppIntent` — un `Link` no es
/// opción ahí (ADR-0057), así que este intent no hace más que reenviar al
/// mismo `lana://capture` que ya usa el widget.
///
/// `isDiscoverable = false` lo mantiene fuera de Siri y de Atajos: el control
/// es su única superficie, y ADR-0018 dejó la exposición a Siri fuera de v1.0.
struct OpenCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Dictar un movimiento"
    static let description = IntentDescription("Abre Lana escuchando, para registrar un gasto.")
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(LanaCaptureLink.url))
    }
}

/// El botón de la pantalla bloqueada: el que vive abajo, junto a la linterna
/// y la cámara. El mismo control aparece en el Centro de Control y se puede
/// asignar al Botón de Acción (ADR-0057) — es una sola pieza para las tres
/// superficies, no tres.
///
/// Sin tema propio: un control lo pinta el sistema con su tinte, no con el
/// acento de la app (ADR-0057).
struct LanaCaptureControl: ControlWidget {
    let kind = "LanaCaptureControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label("Dictar un gasto", systemImage: "dollarsign.circle.fill")
            }
        }
        .displayName("Dictar un gasto")
        .description("Abre Lana escuchando, para registrar un gasto en un toque.")
    }
}

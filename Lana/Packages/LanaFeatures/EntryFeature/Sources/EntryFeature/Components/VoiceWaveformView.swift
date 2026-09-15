import LanaDesign
import SwiftUI

/// Las ondas de voz que se mueven mientras la app escucha — la señal de que
/// hay una IA "oyendo" en vivo, no solo un micrófono encendido. Un mic que
/// solo pulsa (como estaba `ListeningView` antes) no transmite que del otro
/// lado hay algo procesando lo que dices; una barra de ondas en movimiento
/// sí, es el lenguaje visual que Siri y el dictado del sistema ya enseñaron
/// al usuario a leer como "te estoy escuchando".
///
/// El nivel de audio real no está expuesto por `EntryModel` (haría falta
/// bajar hasta la capa de `LanaSpeech`), así que las alturas son un patrón
/// orgánico generado con senoidales desfasadas contra el reloj de `TimelineView`
/// — no reacciona a tu voz palabra por palabra, pero sí da la sensación de
/// escucha activa y continua, que es lo que faltaba. Si más adelante se
/// expone el nivel real, basta con alimentar `level` en `barHeight`.
struct VoiceWaveformView: View {
    @Environment(\.lana) private var lana

    /// Número de barras. Impar a propósito: la del centro es la más alta en
    /// reposo, así el conjunto lee como un pico central y no como una fila
    /// plana.
    private let barCount = 7
    private let barWidth: CGFloat = 5
    private let spacing: CGFloat = 5
    private let minHeight: CGFloat = 8
    private let maxHeight: CGFloat = 40

    var body: some View {
        // `TimelineView(.animation)` avanza cada frame — el movimiento es
        // continuo y fluido sin tener que manejar `@State` ni disparar
        // animaciones a mano.
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0 ..< barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [lana.accent, lana.highlight],
                                startPoint: .top,
                                endPoint: .bottom))
                        .frame(width: barWidth, height: barHeight(index: index, time: t))
                }
            }
            .frame(height: maxHeight)
        }
        .accessibilityHidden(true)
    }

    /// La altura de cada barra: dos senoidales de distinta frecuencia
    /// sumadas y desfasadas por índice, para que las barras no suban y bajen
    /// todas juntas (eso se vería mecánico) sino en un vaivén que parece
    /// responder a una voz. Una envolvente en campana (`centerFalloff`) baja
    /// las barras de los extremos, dejando el pico al centro.
    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = Double(index) * 0.7
        let wave = sin(time * 3.0 + phase) * 0.5 + sin(time * 5.3 + phase * 1.7) * 0.5
        let normalized = (wave + 1) / 2 // 0…1

        let center = Double(barCount - 1) / 2
        let distance = abs(Double(index) - center) / center
        let centerFalloff = 1 - distance * 0.45

        return minHeight + (maxHeight - minHeight) * normalized * centerFalloff
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        VoiceWaveformView()
            .padding()
            .background(LanaColors(theme: theme, colorScheme: .dark).surface)
            .lanaTheme(theme)
    }
}

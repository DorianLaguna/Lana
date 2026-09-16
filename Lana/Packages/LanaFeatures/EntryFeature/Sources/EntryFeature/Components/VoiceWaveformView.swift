import LanaDesign
import SwiftUI

/// La onda de voz mientras la app escucha (rediseño, sección 07): seis barras
/// que oscilan desfasadas, cada una con su ritmo, y cuya altura máxima la
/// marca el volumen real del micrófono. Callado, la onda casi se aplana;
/// hablando, crece — no es decorativa.
struct VoiceWaveformView: View {
    @Environment(\.lana) private var lana
    /// El nivel del micrófono, de 0 a 1.
    let level: Float

    /// Qué fracción del alto máximo alcanza cada barra en su pico.
    private static let peakFractions: [Double] = [0.32, 0.62, 1, 0.8, 0.54, 0.4]
    /// Segundos por oscilación, distintos por barra para que no suban juntas.
    private static let periods: [Double] = [0.8, 1.05, 0.9, 1.2, 0.95, 1.1]
    /// Lo más bajo que queda una barra dentro de su oscilación.
    private static let minimumScale = 0.35
    /// Cuánto se ve la onda aunque no llegue voz: casi plana, pero viva.
    private static let restingAmplitude = 0.22

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: Space.p5.rawValue) {
                ForEach(Self.peakFractions.indices, id: \.self) { index in
                    Capsule()
                        .fill(color(at: index))
                        .frame(width: LanaMetrics.waveformBarWidth, height: barHeight(index: index, time: time))
                }
            }
            .frame(height: LanaMetrics.waveformHeight)
        }
        .animation(.easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }

    private func color(at index: Int) -> Color {
        lana.voiceWave.indices.contains(index) ? lana.voiceWave[index] : lana.accentFill
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = Double(index) * 0.9
        let wave = 0.5 + 0.5 * sin(time * 2 * .pi / Self.periods[index] + phase)
        let oscillation = Self.minimumScale + (1 - Self.minimumScale) * wave
        let clampedLevel = Double(min(max(level, 0), 1))
        let amplitude = Self.restingAmplitude + (1 - Self.restingAmplitude) * clampedLevel
        let height = LanaMetrics.waveformHeight * Self.peakFractions[index] * oscillation * amplitude
        return max(LanaMetrics.waveformBarWidth, height)
    }
}

#Preview {
    VStack(spacing: Space.lg.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            HStack(spacing: Space.xl.rawValue) {
                VoiceWaveformView(level: 0)
                VoiceWaveformView(level: 0.8)
            }
            .padding()
            .background(LanaColors(theme: theme, colorScheme: .dark).surface)
            .lanaTheme(theme)
        }
    }
}

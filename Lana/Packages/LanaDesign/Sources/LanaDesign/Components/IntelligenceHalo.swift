import SwiftUI

/// El estado del "halo inteligente" que envuelve al micrófono. No es un
/// spinner ni un loading indicator — es una señal ambiental de "aquí hay
/// inteligencia trabajando", y cada estado le da un carácter distinto sin
/// necesidad de escribir "IA" en ningún lado.
///
/// El halo nunca desaparece del todo (`idle` sigue teniendo un resplandor
/// muy tenue): esa presencia constante y sutil es justo lo que dice
/// "inteligencia disponible" aun en reposo.
public enum IntelligenceHaloState: Equatable, Sendable {
    /// Disponible, en reposo. Un aura muy sutil que se deforma lentísimo,
    /// casi imperceptible.
    case idle
    /// Escuchando la voz. El halo se abre un poco y respira con más vida —
    /// acompaña al waveform, no compite con él.
    case listening
    /// La IA está procesando. El halo se contrae y gira sobre sí mismo, con
    /// más energía: el momento de "está pensando".
    case processing
    /// Terminó bien. Un destello más luminoso y expandido, breve, de
    /// "listo".
    case success
    /// Algo falló. El halo se apaga a un tono de advertencia, quieto.
    case error
}

/// Un halo de luz suave que envuelve un contenido (el micrófono). Es un
/// resplandor radial monocromático que se desvanece a transparente en el
/// borde —lee como aura, no como un círculo con contorno— con una
/// deformación elíptica muy sutil que lo mantiene "vivo" sin descentrarse ni
/// romperse. El movimiento sale de senoidales lentas contra el reloj de
/// `TimelineView(.animation)`, así que es continuo y fluido sin manejar
/// estado a mano.
///
/// El color sale del acento del tema, salvo en `.error`, que usa
/// `lana.warning` para que el cambio de estado se lea sin texto. La
/// intensidad, la escala y la velocidad las decide `state`.
public struct IntelligenceHalo: View {
    @Environment(\.lana) private var lana

    private let state: IntelligenceHaloState
    /// El diámetro del contenido que envuelve (el mic es 76). El halo se
    /// dibuja más grande que esto según el estado.
    private let baseSize: CGFloat

    public init(state: IntelligenceHaloState, baseSize: CGFloat = 76) {
        self.state = state
        self.baseSize = baseSize
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Un solo resplandor monocromático que se desvanece a
            // transparente en el borde (RadialGradient), no un círculo
            // relleno: eso lo hace leer como aura de luz, no como una mancha
            // de color con borde. Antes eran tres blobs de colores distintos
            // (azul + terracota + warning) superpuestos, que se mezclaban en
            // tonos sucios y se veían como parches peleándose — justo lo que
            // se veía mal. Un solo color del tema, limpio.
            //
            // La "irregularidad" viene de una deformación elíptica muy suave
            // (scaleX/scaleY laten distinto) más un giro lentísimo, así la
            // nube nunca es un círculo perfecto pero tampoco se descentra ni
            // se rompe.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [haloColor.opacity(0.9), haloColor.opacity(0.0)],
                        center: .center,
                        startRadius: baseSize * 0.15,
                        endRadius: haloSize / 2))
                .scaleEffect(x: 1 + breathe(t, freq: 0.55), y: 1 + breathe(t, freq: 0.8, phase: 1.3))
                .rotationEffect(.degrees(rotation(time: t)))
                .frame(width: haloSize, height: haloSize)
                .opacity(overallOpacity)
                .animation(.easeInOut(duration: 0.6), value: state)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Una senoidal lenta de amplitud pequeña (±5%) para la deformación
    /// elíptica. `freq` distinta por eje para que la nube se estire y encoja
    /// cambiando de silueta, no lata como un balón uniforme.
    private func breathe(_ t: TimeInterval, freq: Double, phase: Double = 0) -> CGFloat {
        0.05 * CGFloat(sin(t * freq * animationSpeed + phase))
    }

    // MARK: - Parámetros por estado

    /// El color de la nube: el acento del tema, salvo en `.error`, que tira
    /// a advertencia para que el cambio de estado se lea sin texto.
    private var haloColor: Color {
        state == .error ? lana.warning : lana.accent
    }

    /// Cuánto más grande que el mic se dibuja la nube. Contenido a propósito
    /// —el mic vive sobre la barra de tabs, un halo grande invadía los tabs
    /// vecinos— así que incluso `listening`/`success` se quedan discretos.
    private var haloSize: CGFloat {
        switch state {
        case .idle: baseSize * 1.2
        case .listening: baseSize * 1.4
        case .processing: baseSize * 1.15
        case .success: baseSize * 1.5
        case .error: baseSize * 1.2
        }
    }

    /// La presencia del halo. `idle` es tenue —presente pero discreto—;
    /// `success` el más luminoso.
    private var overallOpacity: Double {
        switch state {
        case .idle: 0.5
        case .listening: 0.75
        case .processing: 0.8
        case .success: 0.95
        case .error: 0.65
        }
    }

    /// Multiplica la frecuencia de la deformación. Reposo: lentísimo.
    /// Procesando: se agita más.
    private var animationSpeed: Double {
        switch state {
        case .idle: 0.5
        case .listening: 1.2
        case .processing: 2.0
        case .success: 1.4
        case .error: 0.3
        }
    }

    /// Solo `.processing` gira sobre sí mismo — el gesto de "pensando". Como
    /// la nube es elíptica (no un círculo perfecto), el giro sí se percibe.
    /// Los demás estados no rotan.
    private func rotation(time: TimeInterval) -> Double {
        guard state == .processing else { return 0 }
        return time.truncatingRemainder(dividingBy: 4) / 4 * 360
    }
}

#Preview("Estados") {
    let states: [(String, IntelligenceHaloState)] = [
        ("Disponible", .idle),
        ("Escuchando", .listening),
        ("Procesando", .processing),
        ("Éxito", .success),
        ("Error", .error)
    ]
    return ScrollView {
        VStack(spacing: Space.xl.rawValue) {
            ForEach(states, id: \.0) { name, state in
                VStack(spacing: Space.sm.rawValue) {
                    ZStack {
                        IntelligenceHalo(state: state)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(
                                LinearGradient(
                                    colors: [
                                        LanaColors(theme: .zafiro, colorScheme: .dark).accent,
                                        LanaColors(theme: .zafiro, colorScheme: .dark).highlight
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing),
                                in: Circle())
                    }
                    Text(name)
                        .lanaFont(.caption)
                }
            }
        }
        .padding(Space.xl.rawValue)
        .frame(maxWidth: .infinity)
    }
    .background(LanaColors(theme: .zafiro, colorScheme: .dark).surface)
    .lanaTheme(.zafiro)
}

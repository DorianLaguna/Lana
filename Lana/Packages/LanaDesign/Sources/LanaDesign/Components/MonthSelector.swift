import SwiftUI

/// Navegación entre meses: ‹ mes ›.
///
/// Vive en `LanaDesign` —y no en la feature donde nació, el Dashboard— porque
/// el Análisis también deja elegir qué mes ver, y las features no pueden
/// importarse entre sí (Docs/ARCHITECTURE.md). Solo recibe primitivos, igual
/// que `TransactionRow`: no conoce el dominio.
public struct MonthSelector: View {
    @Environment(\.lana) private var lana

    private let month: Date
    private let onPrevious: () -> Void
    private let onNext: () -> Void

    public init(month: Date, onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
        self.month = month
        self.onPrevious = onPrevious
        self.onNext = onNext
    }

    private var monthLabel: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    public var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthLabel.capitalized)
                .lanaFont(.headline)
                .foregroundStyle(lana.textPrimary)
            Spacer()
            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
        }
        // El segundo color del tema (`highlight`), no el primario — para
        // que el par completo del tema se vea en más lugares que solo el
        // micrófono (pedido explícito del usuario).
        .foregroundStyle(lana.highlight)
    }
}

#Preview {
    VStack(spacing: Space.md.rawValue) {
        ForEach(LanaTheme.allCases) { theme in
            LanaCard {
                MonthSelector(month: Date(), onPrevious: {}, onNext: {})
            }
            .lanaTheme(theme)
        }
    }
    .padding(Space.md.rawValue)
}

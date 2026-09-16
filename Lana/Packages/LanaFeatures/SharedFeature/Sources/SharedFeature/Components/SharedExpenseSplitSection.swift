import LanaCore
import LanaDesign
import SwiftUI

/// Qué campo del formulario de un gasto compartido tiene el foco.
///
/// `decimalPad` no tiene tecla de retorno — sin resignar el foco a mano antes
/// de guardar, un monto recién tecleado puede no haber llegado todavía al
/// binding de `Decimal` (los `TextField` con `format:` solo confirman el texto
/// al perder el foco, no tecla por tecla) y el split truena en silencio ("no
/// se pudo guardar" aunque se haya llenado todo bien).
enum SharedCaptureField: Hashable {
    case amount
    case share(ParticipantID)
}

/// Cómo se divide un gasto compartido: la regla como chips, los números por
/// participante cuando la regla los pide, y cuánto le toca a cada quien antes
/// de guardar (`SplitRule.portions(of:)`, la única fuente de verdad).
struct SharedExpenseSplitSection: View {
    @Environment(\.lana) private var lana
    @FocusState.Binding var focusedField: SharedCaptureField?
    @Binding var ruleKind: SplitRuleKind
    @Binding var shares: [ParticipantID: Decimal]
    let participants: [Participant]
    let displayName: (ParticipantID) -> String
    let splitRule: SplitRule?
    let amount: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Cómo se divide")
                .padding(.bottom, Space.p10.rawValue)

            FlowLayout {
                ForEach(SplitRuleKind.allCases) { kind in
                    Chip(kind.displayName, tone: ruleKind == kind ? .neutral : .suggestion) {
                        ruleKind = kind
                    }
                    .accessibilityAddTraits(ruleKind == kind ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.bottom, Space.sm.rawValue)

            Text(ruleKind.helpText)
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.ink42)
                .fixedSize(horizontal: false, vertical: true)

            if ruleKind.needsPerParticipantInput {
                sharesCard
                    .padding(.top, Space.p12.rawValue)
            }

            preview
                .padding(.top, Space.p12.rawValue)
        }
    }

    private var sharesCard: some View {
        LanaCard {
            VStack(spacing: 0) {
                ForEach(participants) { participant in
                    HStack(spacing: Space.sm.rawValue) {
                        Text(displayName(participant.id))
                            .lanaFont(.rowTitle)
                            .foregroundStyle(lana.ink)
                        Spacer(minLength: Space.sm.rawValue)
                        TextField(
                            ruleKind.fieldPlaceholder,
                            value: shareBinding(for: participant.id),
                            format: .number)
                            .lanaFont(.rowAmount)
                            .foregroundStyle(lana.ink)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .share(participant.id))
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                    }
                    .frame(minHeight: LanaMetrics.minTouchTarget)
                    if participant.id != participants.last?.id {
                        HairlineDivider()
                    }
                }
            }
        }
    }

    /// Lo que de verdad va a quedar registrado, antes de guardarlo. Si la
    /// regla no cierra, aquí se dice por qué en vez de esperar al botón.
    @ViewBuilder
    private var preview: some View {
        if let splitRule, let portions = try? splitRule.portions(of: Money(amount: amount, currency: .mxn)) {
            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    Text("Le toca a cada quien")
                        .lanaFont(.minorHeader)
                        .foregroundStyle(lana.ink42)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(participants) { participant in
                        if let portion = portions[participant.id] {
                            HStack(spacing: Space.sm.rawValue) {
                                Text(displayName(participant.id))
                                    .lanaFont(.rowSubtitle)
                                    .foregroundStyle(lana.ink70)
                                Spacer(minLength: Space.xs.rawValue)
                                Text(portion.formatted())
                                    .lanaFont(.rowSubtitle)
                                    .monospacedDigit()
                                    .foregroundStyle(lana.ink)
                            }
                        }
                    }
                }
            }
        } else if let splitRule, amount > 0 {
            Text(previewError(for: splitRule))
                .lanaFont(.rowSubtitle)
                .foregroundStyle(lana.attention)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shareBinding(for participant: ParticipantID) -> Binding<Decimal> {
        Binding(
            get: { shares[participant] ?? 0 },
            set: { shares[participant] = $0 })
    }

    private func previewError(for splitRule: SplitRule) -> String {
        do {
            _ = try splitRule.portions(of: Money(amount: amount, currency: .mxn))
            return ""
        } catch {
            return error.localizedDescription
        }
    }
}

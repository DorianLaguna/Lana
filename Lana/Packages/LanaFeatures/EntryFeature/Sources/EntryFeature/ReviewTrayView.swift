import LanaCore
import LanaDesign
import SwiftUI

/// La bandeja "Por revisar" (rediseño, sección 08, modo bandeja): la misma
/// hoja de revisión que la captura, sobre movimientos que ya están guardados.
///
/// Dos diferencias con la revisión de un dictado: el encabezado va en
/// `attention` en vez de `positive` —esto reclama acción, no celebra— y no hay
/// transcripción que citar, porque nadie dictó esto.
public struct ReviewTrayView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: ReviewTrayModel
    private let onDone: () -> Void

    public init(model: ReviewTrayModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, LanaMetrics.screenMargin)
                .padding(.top, Space.p14.rawValue)
                .padding(.bottom, Space.md.rawValue)

            ScrollView {
                VStack(spacing: Space.p12.rawValue) {
                    ForEach($model.drafts) { $draft in
                        VStack(alignment: .leading, spacing: Space.p6.rawValue) {
                            Text(Self.originLabel(for: draft))
                                .lanaFont(.rowSubtitle)
                                .foregroundStyle(lana.ink42)
                            DraftCard(
                                draft: $draft,
                                cards: model.cards,
                                allSubcategories: model.allSubcategories,
                                sharedLists: model.sharedLists,
                                onDelete: model.drafts.count > 1 ? { model.remove(id: draft.id) } : nil)
                        }
                    }
                }
                .padding(.horizontal, LanaMetrics.screenMargin)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .lanaFont(.rowSubtitle)
                    .foregroundStyle(lana.attention)
                    .padding(.horizontal, LanaMetrics.screenMargin)
                    .padding(.top, Space.p10.rawValue)
            }

            Button {
                Task {
                    if await model.confirm() {
                        onDone()
                    }
                }
            } label: {
                if model.isSaving {
                    ProgressView()
                        .tint(lana.onAccent)
                } else {
                    Text(model.confirmLabel)
                }
            }
            .buttonStyle(.lana(size: .large, isExpanded: true))
            .disabled(model.isSaving || model.drafts.isEmpty)
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.md.rawValue)
            .padding(.bottom, Space.p40.rawValue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(lana.surface)
    }

    private var header: some View {
        HStack(spacing: Space.sm.rawValue) {
            Circle()
                .fill(lana.attention)
                .frame(width: LanaMetrics.dot, height: LanaMetrics.dot)
            Text(model.drafts.count == 1 ? "1 por revisar" : "\(model.drafts.count) por revisar")
                .lanaFont(.sectionHeader)
                .foregroundStyle(lana.attention)
            Spacer(minLength: Space.sm.rawValue)
            Text("en el teléfono")
                .lanaFont(.footnote)
                .foregroundStyle(lana.ink42)
        }
        .accessibilityElement(children: .combine)
    }

    /// De dónde vino: la hora a la que se registró. Lana no guarda el origen
    /// del movimiento, así que no lo inventa — dice lo que sí sabe.
    static func originLabel(for draft: DraftTransaction, calendar: Calendar = .current, now: Date = Date()) -> String {
        let time = draft.date.formatted(
            Date.FormatStyle(locale: LanaDateFormat.locale, calendar: calendar).hour().minute())
        return "\(LanaDateFormat.dayLabel(draft.date, calendar: calendar, now: now)) · \(time)"
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        ReviewTrayView(
            model: ReviewTrayModel(
                expenses: [
                    Expense(
                        kind: .expense,
                        amount: Money(amount: 120, currency: .mxn),
                        concept: "OXXO Reforma",
                        date: Date(),
                        needsReview: true)
                ],
                store: InMemoryExpenseStore()),
            onDone: {})
            .lanaTheme(theme)
    }
}

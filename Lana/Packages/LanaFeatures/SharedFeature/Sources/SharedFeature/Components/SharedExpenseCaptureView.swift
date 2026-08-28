import LanaCore
import LanaDesign
import SwiftUI

/// Captura manual de un gasto compartido — pagador + regla de división de
/// un segmented control con las 5 opciones de `SplitRule`, con
/// previsualización de cuánto le toca a cada quien vía
/// `SplitRule.portions(of:)` antes de guardar. Sin lenguaje natural
/// todavía (v1: el picker manual alcanza para el riesgo de este bloque).
public struct SharedExpenseCaptureView: View {
    private enum RuleKind: String, CaseIterable, Identifiable {
        case equally
        case payerOnly
        case proportional
        case percentage
        case exactAmounts

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .equally: "Iguales"
            case .payerOnly: "Solo quien pagó"
            case .proportional: "Proporcional"
            case .percentage: "Porcentaje"
            case .exactAmounts: "Montos exactos"
            }
        }

        /// Si necesita que el usuario capture un valor por participante —
        /// `.equally`/`.payerOnly` se resuelven solas contra todo el roster.
        var needsPerParticipantInput: Bool {
            switch self {
            case .equally, .payerOnly: false
            case .proportional, .percentage, .exactAmounts: true
            }
        }
    }

    @Environment(\.lana) private var lana
    @Environment(\.dismiss) private var dismiss
    private let model: SharedListDetailModel
    private let onDone: () -> Void

    @State private var amount: Decimal = 0
    @State private var concept = ""
    @State private var date = Date()
    @State private var payer: ParticipantID
    @State private var ruleKind: RuleKind = .equally
    @State private var shares: [ParticipantID: Decimal] = [:]
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(model: SharedListDetailModel, onDone: @escaping () -> Void) {
        self.model = model
        self.onDone = onDone
        _payer = State(initialValue: model.list.participants.first?.id ?? ParticipantID())
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Monto")
                        Spacer()
                        TextField("0", value: $amount, format: .number)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                    }
                    LanaTextField("Concepto", text: $concept)
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                    Picker("Pagó", selection: $payer) {
                        ForEach(model.list.participants) { participant in
                            Text(participant.displayName).tag(participant.id)
                        }
                    }
                }

                Section {
                    Picker("División", selection: $ruleKind) {
                        ForEach(RuleKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .padding(Space.sm.rawValue)

                    if ruleKind.needsPerParticipantInput {
                        ForEach(model.list.participants) { participant in
                            HStack {
                                Text(participant.displayName)
                                Spacer()
                                TextField("0", value: shareBinding(for: participant.id), format: .number)
                                    .monospacedDigit()
                                    .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                    .keyboardType(.decimalPad)
                                #endif
                            }
                        }
                    }

                    preview
                }

                if let errorMessage {
                    Text(errorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.critical)
                }
            }
            .navigationTitle("Gasto compartido")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Guardar")
                            }
                        }
                        .disabled(isSaving || splitRule == nil)
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }

    private func shareBinding(for participant: ParticipantID) -> Binding<Decimal> {
        Binding(
            get: { shares[participant] ?? 0 },
            set: { shares[participant] = $0 })
    }

    /// `nil` cuando la regla no valida — `SplitRule.portions(of:)` es la
    /// única fuente de verdad de si un split cierra, no se reimplementa
    /// aquí (proporciones que suman 1, porcentajes que suman 100, montos
    /// exactos que suman el total).
    private var splitRule: SplitRule? {
        let participantIDs = model.list.participants.map(\.id)
        switch ruleKind {
        case .equally:
            return .equally(among: participantIDs)
        case .payerOnly:
            return .payerOnly
        case .proportional:
            return .proportional(shares: shares)
        case .percentage:
            return .percentage(shares: shares)
        case .exactAmounts:
            return .exactAmounts(amounts: shares)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let splitRule, let portions = try? splitRule.portions(of: Money(amount: amount, currency: .mxn)) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(model.list.participants) { participant in
                    if let portion = portions[participant.id] {
                        HStack {
                            Text(participant.displayName)
                            Spacer()
                            Text(portion.formatted())
                                .monospacedDigit()
                        }
                        .lanaFont(.caption)
                        .foregroundStyle(lana.textSecondary)
                    }
                }
            }
        } else if let splitRule, amount > 0 {
            Text(previewError(for: splitRule))
                .lanaFont(.caption)
                .foregroundStyle(lana.warning)
        }
    }

    private func previewError(for splitRule: SplitRule) -> String {
        do {
            _ = try splitRule.portions(of: Money(amount: amount, currency: .mxn))
            return ""
        } catch {
            return error.localizedDescription
        }
    }

    private func save() async {
        guard let splitRule else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        guard (try? splitRule.portions(of: Money(amount: amount, currency: .mxn))) != nil else {
            errorMessage = previewError(for: splitRule)
            return
        }
        let saved = await model.recordExpense(
            amount: Money(amount: amount, currency: .mxn),
            concept: concept,
            date: date,
            payer: payer,
            split: splitRule)
        if saved {
            onDone()
        } else {
            errorMessage = "No se pudo guardar."
        }
    }
}

#Preview {
    let alice = Participant(displayName: "Tú")
    let bob = Participant(displayName: "Sam")
    let list = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .equally(among: [alice.id, bob.id]))
    ForEach(LanaTheme.allCases) { theme in
        SharedExpenseCaptureView(
            model: SharedListDetailModel(
                list: list,
                sharedListStore: InMemorySharedListStore(seed: [list]),
                expenseStore: InMemoryExpenseStore()),
            onDone: {})
            .lanaTheme(theme)
    }
}

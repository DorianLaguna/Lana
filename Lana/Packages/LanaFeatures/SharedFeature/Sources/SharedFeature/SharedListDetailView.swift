import LanaCore
import LanaDesign
import SwiftUI

/// El drill-down de una lista compartida: saldos, gastos, capturar,
/// liquidar (Fase 8). Sin lógica propia, refleja `SharedListDetailModel`.
public struct SharedListDetailView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: SharedListDetailModel
    @State private var isCapturing = false
    @State private var settlingDebt: Debt?
    @State private var viewingDebt: Debt?
    @State private var isPromptingViewer = false
    /// Tocar un gasto lo edita aquí mismo — `SharedExpenseCaptureView` ya
    /// tiene toda la UI de pagador/split que el editor genérico de
    /// Dashboard no puede mostrar (no conoce el roster de participantes),
    /// así que editar un gasto compartido se queda dentro de esta feature,
    /// sin cruzar a `DashboardFeature` como antes.
    @State private var editingExpense: Expense?
    @State private var editingList: EditSharedListModel?

    public init(model: SharedListDetailModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Space.md.rawValue) {
                if let shareErrorMessage = model.shareErrorMessage {
                    Text(shareErrorMessage)
                        .lanaFont(.caption)
                        .foregroundStyle(lana.ink50)
                }

                BalancesView(
                    balances: model.balances,
                    debts: model.debts,
                    participantName: { model.displayName(for: $0) },
                    onSettle: { settlingDebt = $0 },
                    onSelectDebt: { viewingDebt = $0 })

                if !model.expenses.isEmpty {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Gastos")
                                .lanaFont(.caption)
                                .foregroundStyle(lana.ink50)
                            VStack(spacing: 0) {
                                ForEach(model.expenses) { expense in
                                    Button {
                                        editingExpense = expense
                                    } label: {
                                        SharedExpenseRow(
                                            expense: expense,
                                            payerName: expense.payer.map { model.displayName(for: $0) })
                                    }
                                    .buttonStyle(.plain)
                                    if expense.id != model.expenses.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(Space.md.rawValue)
        }
        .background(lana.bg)
        .navigationTitle(model.list.name)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                // Los dos en `.primaryAction` a propósito — `.secondaryAction`
                // se ve como un botón de "..." que colapsa el de compartir
                // dentro de un menú, y no se leía como "invitar" (el ícono
                // solo, sin texto, dentro de ese menú no bastaba).
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCapturing = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingList = EditSharedListModel(
                            list: model.list,
                            viewerID: model.viewerParticipantID,
                            onSave: { updated, viewerID in
                                let saved = await model.updateList(updated)
                                if saved, let viewerID {
                                    await model.setViewer(viewerID)
                                }
                                return saved
                            })
                    } label: {
                        Label("Editar lista", systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    // Una vez preparada la URL, este mismo slot se vuelve un
                    // `ShareLink` — SwiftUI puro, sin que la feature importe
                    // `CloudKit`/`UIKit` (ADR-0020).
                    if let shareURL = model.shareURL {
                        ShareLink(item: shareURL) {
                            Label("Invitar", systemImage: "person.badge.plus")
                        }
                    } else {
                        Button {
                            Task { await model.prepareShare() }
                        } label: {
                            Label("Invitar", systemImage: "person.badge.plus")
                        }
                    }
                }
            }
            .task {
                await model.onAppear()
                isPromptingViewer = model.needsViewerPrompt
            }
            .refreshable { await model.onAppear() }
            .sheet(isPresented: $isCapturing) {
                SharedExpenseCaptureView(model: model, onDone: { isCapturing = false })
            }
            .sheet(item: $editingExpense) { expense in
                SharedExpenseCaptureView(model: model, existingExpense: expense, onDone: { editingExpense = nil })
            }
            .sheet(isPresented: isSettlingBinding) {
                if let debt = settlingDebt {
                    SettleUpView(model: model, debt: debt, onDone: { settlingDebt = nil })
                }
            }
            .sheet(isPresented: isViewingDebtBinding) {
                if let debt = viewingDebt {
                    DebtDetailView(
                        debt: debt,
                        contributions: model.contributions(for: debt),
                        participantName: { model.displayName(for: $0) })
                }
            }
            .sheet(item: $editingList) { editModel in
                EditSharedListView(model: editModel, onDone: { editingList = nil })
            }
            .sheet(isPresented: $isPromptingViewer) {
                ViewerPromptView(participants: model.list.participants) { participantID in
                    Task { await model.setViewer(participantID) }
                    isPromptingViewer = false
                }
            }
    }

    /// `Debt` no es `Identifiable` — no tiene un id propio, es un valor
    /// calculado a partir de los saldos, no una entidad persistida — por
    /// eso `.sheet(isPresented:)` en vez de `.sheet(item:)`.
    private var isSettlingBinding: Binding<Bool> {
        Binding(
            get: { settlingDebt != nil },
            set: { isPresented in
                if !isPresented {
                    settlingDebt = nil
                }
            })
    }

    /// Mismo motivo que `isSettlingBinding` — `Debt` no es `Identifiable`.
    private var isViewingDebtBinding: Binding<Bool> {
        Binding(
            get: { viewingDebt != nil },
            set: { isPresented in
                if !isPresented {
                    viewingDebt = nil
                }
            })
    }
}

/// Reusa `TransactionRow` (`LanaDesign`) — la misma unidad visual que el
/// Dashboard y Tarjetas, con su punto de color de categoría — en vez de una
/// fila hecha a mano sin categoría. Debajo, una segunda línea con fecha y
/// quién pagó, que `TransactionRow` no tiene espacio genérico para cargar
/// (es un componente sin conocimiento del dominio, Docs/ARCHITECTURE.md).
private struct SharedExpenseRow: View {
    @Environment(\.lana) private var lana
    let expense: Expense
    let payerName: String?

    /// Sin punto de color: las categorías ya no tienen uno propio (ADR-0044).
    /// El subtítulo dice categoría y quién pagó, que es lo que distingue a un
    /// gasto compartido de uno personal.
    var body: some View {
        MovementRow(
            title: expense.concept,
            subtitle: subtitle,
            amountText: expense.amount.formatted(),
            isShared: true)
    }

    private var subtitle: String {
        var parts = [categoryDisplayName]
        if let payerName {
            parts.append("pagó \(payerName)")
        }
        return parts.joined(separator: " · ")
    }

    private var categoryDisplayName: String {
        guard let category = expense.category else { return "Sin categoría" }
        if let known = SuggestedCategory(rawValue: category) {
            return known.displayName
        }
        return category.capitalized
    }
}

/// Se muestra la primera vez que se abre una lista sin identidad marcada
/// (creada antes de que esto existiera, o recibida por invitación) —
/// dismissable sin elegir, y si eso pasa se vuelve a preguntar la próxima
/// vez que se abra la lista (`SharedListDetailModel.needsViewerPrompt` se
/// recalcula en cada `init`, no solo una vez).
private struct ViewerPromptView: View {
    @Environment(\.lana) private var lana
    let participants: [Participant]
    let onSelect: (ParticipantID) -> Void
    @State private var selected: ParticipantID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("¿Cuál de estos eres tú?", selection: $selected) {
                        ForEach(participants) { participant in
                            Text(participant.displayName).tag(Optional(participant.id))
                        }
                    }
                } footer: {
                    Text("""
                    Así Lana muestra en tu Dashboard personal solo la parte que te toca de un gasto \
                    compartido, no el total.
                    """)
                }
            }
            .navigationTitle("¿Quién eres aquí?")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") {
                            if let selected {
                                onSelect(selected)
                            }
                        }
                        .disabled(selected == nil)
                    }
                }
        }
        .onAppear {
            if selected == nil {
                selected = participants.first?.id
            }
        }
    }
}

#Preview {
    let alice = Participant(displayName: "Tú")
    let bob = Participant(displayName: "Sam")
    let list = SharedList(name: "Depa", participants: [alice, bob], defaultSplit: .equally(among: [alice.id, bob.id]))
    ForEach(LanaTheme.allCases) { theme in
        NavigationStack {
            SharedListDetailView(model: SharedListDetailModel(
                list: list,
                sharedListStore: InMemorySharedListStore(seed: [list]),
                expenseStore: InMemoryExpenseStore(),
                parser: InMemoryExpenseParsing()))
        }
        .lanaTheme(theme)
    }
}

import LanaCore
import LanaDesign
import SwiftUI

/// El drill-down de una lista compartida: saldos, gastos, capturar,
/// liquidar (Fase 8). Sin lógica propia, refleja `SharedListDetailModel`.
public struct SharedListDetailView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: SharedListDetailModel
    @State private var isCapturing = false
    @State private var viewingDebt: Debt?
    @State private var isPromptingViewer = false
    /// Tocar un gasto lo edita aquí mismo — `SharedExpenseCaptureView` ya
    /// tiene toda la UI de pagador/split que el editor genérico de
    /// Dashboard no puede mostrar (no conoce el roster de participantes),
    /// así que editar un gasto compartido se queda dentro de esta feature,
    /// sin cruzar a `DashboardFeature` como antes.
    @State private var editingExpense: Expense?
    @State private var editingList: EditSharedListModel?
    /// Quienes se acaban de agregar a la lista, mientras se decide si se suman
    /// a lo ya registrado (ADR-0050). Se pregunta al cerrar la hoja de edición.
    @State private var pendingNewcomers: [ParticipantID] = []
    @State private var isAskingToInclude = false

    public init(model: SharedListDetailModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Space.md.rawValue) {
                if let shareErrorMessage = model.shareErrorMessage {
                    Text(shareErrorMessage)
                        .lanaFont(.rowSubtitle)
                        .foregroundStyle(lana.ink50)
                }

                BalancesView(
                    balances: model.balances,
                    debts: model.debts,
                    participantName: { model.displayName(for: $0) },
                    viewerID: model.viewerParticipantID,
                    onSettle: { debt in Task { await model.settle(debt) } },
                    onSelectDebt: { viewingDebt = $0 })

                if !model.expenses.isEmpty {
                    LanaCard {
                        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                            Text("Gastos")
                                .lanaFont(.sectionHeader)
                                .foregroundStyle(lana.ink50)
                                .accessibilityAddTraits(.isHeader)
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
            // Sin esto, los últimos gastos quedaban detrás de la barra de
            // pestañas y no había forma de subirlos.
            .tabBarClearance()
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
                            removalBlocker: { model.removalBlocker(for: $0) },
                            pastExpenseCounts: { id in
                                PastExpenseCounts(
                                    includable: model.expensesToInclude([id]).count,
                                    excludable: model.expensesToExclude([id]).count)
                            },
                            onSave: { edit in await save(edit) })
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
            .sheet(isPresented: isViewingDebtBinding) {
                if let debt = viewingDebt {
                    DebtDetailView(
                        explanation: model.explanation(for: debt),
                        viewerID: model.viewerParticipantID,
                        participantName: { model.displayName(for: $0) })
                }
            }
            .sheet(item: $editingList, onDismiss: {
                // Después de que la hoja se cierra, no durante: una alerta
                // presentada mientras se cierra una hoja no aparece.
                isAskingToInclude = !pendingNewcomers.isEmpty
            }) { editModel in
                EditSharedListView(model: editModel, onDone: { editingList = nil })
            }
            .alert(includeTitle, isPresented: $isAskingToInclude) {
                Button("Sí, dividir entre todos") {
                    let newcomers = pendingNewcomers
                    pendingNewcomers = []
                    Task { await model.include(newcomers) }
                }
                Button("Solo lo nuevo", role: .cancel) {
                    pendingNewcomers = []
                }
            } message: {
                Text("""
                Se vuelven a dividir en partes iguales, contando a quien agregaste. \
                Los de porcentaje, montos exactos o proporcional se quedan como están.
                """)
            }
            .sheet(isPresented: $isPromptingViewer) {
                ViewerPromptView(participants: model.list.participants) { participantID in
                    Task { await model.setViewer(participantID) }
                    isPromptingViewer = false
                }
            }
    }

    /// Guarda la edición en orden: primero saca a quien se quitó de sus gastos
    /// —así ningún gasto apunta a alguien que ya no está en la lista—, luego
    /// la lista, y al final suma a quien se pidió a lo ya registrado.
    private func save(_ edit: SharedListEdit) async -> Bool {
        let previous = Set(model.list.participants.map(\.id))
        if !edit.removed.isEmpty {
            guard await model.exclude(edit.removed) else { return false }
        }
        guard await model.updateList(edit.list) else { return false }
        if let viewerID = edit.viewerID {
            await model.setViewer(viewerID)
        }
        if !edit.includeInPast.isEmpty {
            _ = await model.include(edit.includeInPast)
        }
        let newcomers = edit.list.participants.map(\.id).filter { !previous.contains($0) }
        pendingNewcomers = model.expensesToInclude(newcomers).isEmpty ? [] : newcomers
        return true
    }

    /// "¿Sumar a Kin a los 12 gastos que ya están?"
    private var includeTitle: String {
        let names = pendingNewcomers.map { model.displayName(for: $0) }
        let who = names.count <= 1
            ? names.first ?? ""
            : names.dropLast().joined(separator: ", ") + " y " + (names.last ?? "")
        let count = model.expensesToInclude(pendingNewcomers).count
        let expenses = count == 1 ? "al gasto que ya está" : "a los \(count) gastos que ya están"
        return "¿Sumar a \(who) \(expenses)?"
    }

    /// `Debt` no es `Identifiable` — no tiene un id propio, es un valor
    /// calculado a partir de los saldos, no una entidad persistida — por eso
    /// `.sheet(isPresented:)` en vez de `.sheet(item:)`.
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

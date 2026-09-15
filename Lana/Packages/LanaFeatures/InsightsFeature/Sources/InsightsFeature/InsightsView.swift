import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// El Análisis con IA: el resumen narrado del periodo, la mezcla del
/// presupuesto contra la regla que el usuario eligió, los patrones y las
/// sugerencias.
///
/// Es una pantalla aparte de la vista anual a propósito: ahí van las
/// estadísticas puras, que funcionan siempre; aquí lo que depende de Apple
/// Intelligence. Sin el modelo, esta pantalla explica por qué y la otra sigue
/// completa.
public struct InsightsView: View {
    @Environment(\.lana) private var lana
    @Bindable private var model: InsightsModel

    private let onOpenSettings: (() -> Void)?
    private let onDone: () -> Void

    public init(
        model: InsightsModel,
        onOpenSettings: (() -> Void)? = nil,
        onDone: @escaping () -> Void = {}) {
        self.model = model
        self.onOpenSettings = onOpenSettings
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.md.rawValue) {
                    if model.availability == .available {
                        periodPicker
                        anchorSelector
                        content
                    } else {
                        InsightsUnavailableView(
                            availability: model.availability,
                            onOpenSettings: onOpenSettings,
                            onRetry: { Task { await model.onAppear() } })
                    }
                }
                .padding(Space.md.rawValue)
            }
            .background(lana.surface)
            .navigationTitle("Análisis")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo", action: onDone)
                    }
                }
        }
        // Como cualquier otra hoja de la app: que se vea que se puede arrastrar
        // para cerrar.
        .presentationDragIndicator(.visible)
        .task { await model.onAppear() }
    }

    private var periodPicker: some View {
        Picker("Periodo", selection: Binding(
            get: { model.period },
            set: { period in Task { await model.select(period) } })) {
                ForEach(InsightsPeriod.allCases) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
    }

    /// Qué mes o qué año se analiza. Sin esto, el análisis solo sabía ver el
    /// periodo en curso — y un mes ya cerrado es justo el que vale la pena
    /// entender.
    @ViewBuilder
    private var anchorSelector: some View {
        switch model.period {
        case .month:
            MonthSelector(
                month: model.anchor,
                onPrevious: { Task { await model.goToPrevious() } },
                onNext: { Task { await model.goToNext() } })
        case .year:
            YearSelector(
                year: model.anchorYear,
                onPrevious: { Task { await model.goToPrevious() } },
                onNext: { Task { await model.goToNext() } })
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            LanaCard {
                HStack(spacing: Space.sm.rawValue) {
                    ProgressView()
                    Text("Leyendo \(model.anchorLabel)…")
                        .lanaFont(.body)
                        .foregroundStyle(lana.textSecondary)
                }
            }
        } else if let message = model.errorMessage {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "No se pudo analizar",
                message: message,
                actionTitle: "Volver a intentar",
                action: { Task { await model.onAppear() } })
        } else if model.mix == nil {
            EmptyStateView(
                systemImage: "sparkles",
                title: "Nada que analizar en \(model.anchorLabel)",
                message: "Registra algún movimiento y Lana te cuenta qué pasó con tu dinero.")
        } else {
            heroSection
            suggestionSection
            readingSection
            AskSection(
                question: $model.question,
                suggestions: model.suggestedQuestions,
                answer: model.answer,
                isAnswering: model.isAnswering,
                onAsk: { Task { await model.ask() } },
                onAskSuggestion: { suggestion in Task { await model.ask(suggestion) } },
                onClear: { model.clearQuestion() })
            otherCurrenciesNote
        }
    }

    // MARK: - El héroe

    /// La narrativa y la mezcla, en una sola tarjeta.
    ///
    /// Eran dos tarjetas grises seguidas, cada una a medias: un párrafo suelto
    /// arriba y una barra sin contexto abajo. Juntas son el bloque que la
    /// pantalla vino a mostrar, así que el resumen sube a `.title` y la mezcla
    /// queda debajo, detrás de una línea — el mismo dato, no dos.
    ///
    /// Aquí el héroe no es una cifra sino prosa: `.largeAmount` está reservado
    /// para dinero, y el total del periodo ya se ve en el Dashboard y en el
    /// año. Repetirlo aquí sería una tercera copia del mismo número.
    @ViewBuilder
    private var heroSection: some View {
        if let mix = model.mix, let currency = model.analyzedCurrency {
            LanaCard {
                VStack(alignment: .leading, spacing: Space.md.rawValue) {
                    if let summary = model.narrative?.summary, !summary.isEmpty {
                        Text(summary)
                            .lanaFont(.title)
                            .foregroundStyle(lana.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                        HStack {
                            SectionCaption("Cómo repartiste")
                            Spacer()
                            rulePicker
                        }
                        BudgetMixBar(shares: model.shares, currency: currency)
                        mixFootnotes(mix, currency: currency)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func mixFootnotes(_ mix: BudgetMix, currency: Currency) -> some View {
        if !mix.isMeasuredAgainstIncome {
            // Sin ingreso registrado no hay meta que perseguir: se dice, en vez
            // de inventar un denominador.
            Text("""
            Estos porcentajes son sobre lo que gastaste. Registra tu ingreso del \
            periodo y Lana puede compararlos contra una regla.
            """)
            .lanaFont(.caption)
            .foregroundStyle(lana.textSecondary)
        }
        if mix.unclassified > 0 {
            Text("Sin clasificar: \(Money(amount: mix.unclassified, currency: currency).formatted())")
                .lanaFont(.caption)
                .monospacedDigit()
                .foregroundStyle(lana.textSecondary)
        }
    }

    // MARK: - Lo que se lee

    /// Patrones e ideas, en una sola tarjeta separada por una línea.
    ///
    /// Eran dos tarjetas idénticas seguidas, cada una con dos o tres frases.
    /// Son lo mismo —lo que el modelo notó— así que van juntas y separadas por
    /// un `Divider()`, como la app hace en todas sus listas.
    @ViewBuilder
    private var readingSection: some View {
        let patterns = model.narrative?.patterns ?? []
        let ideas = model.narrative?.suggestions ?? []

        if !patterns.isEmpty || !ideas.isEmpty {
            LanaCard {
                VStack(alignment: .leading, spacing: Space.md.rawValue) {
                    if !patterns.isEmpty {
                        sentenceBlock("Lo que se nota", items: patterns)
                    }
                    if !patterns.isEmpty, !ideas.isEmpty {
                        Divider()
                    }
                    if !ideas.isEmpty {
                        sentenceBlock("Ideas", items: ideas)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sentenceBlock(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            SectionCaption(title)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .lanaFont(.body)
                    .foregroundStyle(lana.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - La regla y la mezcla

    @ViewBuilder
    private var suggestionSection: some View {
        if let suggestion = model.suggestion {
            LanaCard {
                VStack(alignment: .leading, spacing: Space.sm.rawValue) {
                    SectionCaption("Una regla que podría quedarte")
                    Text(suggestion.rule.displayName)
                        .lanaFont(.headline)
                        .foregroundStyle(lana.textPrimary)
                    Text(suggestion.reason)
                        .lanaFont(.body)
                        .foregroundStyle(lana.textSecondary)
                    HStack(spacing: Space.sm.rawValue) {
                        Button("Usarla") { model.selectRule(suggestion.rule) }
                            .buttonStyle(.borderedProminent)
                            .tint(lana.accent)
                        // Descartar se recuerda: no se vuelve a proponer.
                        Button("Ahora no") { model.dismissSuggestion() }
                            .buttonStyle(.plain)
                            .foregroundStyle(lana.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Cambiar de regla es instantáneo: las cuatro usan los mismos tres
    /// grupos, así que solo cambian las metas — no se reclasifica ni se vuelve
    /// a llamar al modelo.
    private var rulePicker: some View {
        Menu {
            Button("Sin regla") { model.selectRule(nil) }
            ForEach(BudgetRule.allCases) { rule in
                Button {
                    model.selectRule(rule)
                } label: {
                    Text("\(rule.displayName) — \(rule.summary)")
                }
            }
        } label: {
            HStack(spacing: Space.xs.rawValue) {
                Text(model.selectedRule?.displayName ?? "Sin regla")
                    .lanaFont(.caption)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(lana.highlight)
        }
        .accessibilityLabel("Regla de presupuesto")
    }

    @ViewBuilder
    private var otherCurrenciesNote: some View {
        if !model.otherCurrencies.isEmpty {
            Text("""
            Este análisis es de \(model.analyzedCurrency?.rawValue ?? ""). \
            También tuviste movimientos en \
            \(model.otherCurrencies.map(\.rawValue).joined(separator: ", ")); \
            esos se ven en la vista del año.
            """)
            .lanaFont(.caption)
            .foregroundStyle(lana.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ForEach(LanaTheme.allCases) { theme in
        InsightsView(model: InsightsModel(
            store: InMemoryExpenseStore(),
            sharedListStore: InMemorySharedListStore(),
            classifier: InMemorySpendingClassifying(),
            narrator: InMemoryInsightNarrating()))
            .lanaTheme(theme)
    }
}

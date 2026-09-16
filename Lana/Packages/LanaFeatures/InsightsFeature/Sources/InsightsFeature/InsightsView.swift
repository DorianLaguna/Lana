import Foundation
import LanaCore
import LanaDesign
import SwiftUI

/// El Análisis con Lana (rediseño, sección 10): el mes o el año explicados en
/// palabras, la mezcla contra la regla elegida, y preguntas en lenguaje
/// natural.
///
/// Es una pantalla aparte de El año a propósito: ahí van las estadísticas
/// puras, que funcionan siempre; aquí lo que depende de Apple Intelligence.
/// Sin el modelo, esta explica por qué y la otra sigue completa.
///
/// **Las cifras las calcula la app, no el modelo** — él solo redacta
/// (ADR-0013).
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, Space.p20.rawValue)

                periodPicker
                    .padding(.bottom, Space.p18.rawValue)
                content
            }
            .padding(.horizontal, LanaMetrics.screenMargin)
            .padding(.top, Space.p18.rawValue)
            .padding(.bottom, Space.p40.rawValue)
        }
        .background(lana.bg)
        .presentationDragIndicator(.visible)
        .task { await model.onAppear() }
    }

    private var header: some View {
        HStack {
            Text("Análisis")
                .lanaFont(.sheetTitle)
                .foregroundStyle(lana.ink)
            Spacer()
            Button("Listo", action: onDone)
                .lanaFont(.action)
                .foregroundStyle(lana.accent)
                .buttonStyle(.plain)
                .frame(minHeight: LanaMetrics.minTouchTarget)
        }
    }

    /// Las etiquetas son el periodo real ("Septiembre" / "2026"), no las
    /// palabras "Mes" y "Año": así se sabe qué se está leyendo sin buscar otro
    /// control que lo diga.
    private var periodPicker: some View {
        HStack(spacing: Space.p3.rawValue) {
            ForEach(InsightsPeriod.allCases) { period in
                let isSelected = model.period == period
                Button {
                    Task { await model.select(period) }
                } label: {
                    Text(label(for: period))
                        .lanaFont(.detail)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? lana.ink : lana.ink50)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm.rawValue)
                        .background {
                            if isSelected {
                                Capsule().fill(lana.surface3)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Space.p3.rawValue)
        .background(lana.bg, in: Capsule())
        .overlay(Capsule().strokeBorder(lana.hairlineStrong, lineWidth: LanaMetrics.hairline))
    }

    private func label(for period: InsightsPeriod) -> String {
        switch period {
        case .month: LanaDateFormat.monthName(model.anchor)
        case .year: String(model.anchorYear)
        }
    }

    /// Las preguntas van **siempre**, con o sin Apple Intelligence: cada chip
    /// es un cálculo determinista. Lo único que la falta del modelo se lleva es
    /// el resumen escrito y la mezcla, que sí dependen del clasificador — no la
    /// pantalla entera, como antes.
    @ViewBuilder
    private var content: some View {
        // Los hallazgos van arriba y **siempre**: son lo que el usuario no
        // sabía, y no dependen del modelo. El resumen narrado repite lo que ya
        // se vio en Mes; esto no.
        FindingsSection(findings: model.findings)

        if model.availability == .available {
            narratedAnalysis
        } else {
            InsightsUnavailableView(
                availability: model.availability,
                onOpenSettings: onOpenSettings,
                onRetry: { Task { await model.onAppear() } })
                .padding(.bottom, Space.p28.rawValue)
        }

        AskSection(
            question: $model.question,
            suggestions: model.quickAnswers,
            canAskFreeText: model.availability == .available,
            answer: model.answer,
            isAnswering: model.isAnswering,
            onAsk: { Task { await model.ask() } },
            onAskSuggestion: { suggestion in Task { await model.ask(suggestion) } },
            onClear: { model.clearQuestion() })
    }

    @ViewBuilder
    private var narratedAnalysis: some View {
        if model.isLoading {
            shimmer
        } else if let message = model.errorMessage {
            EmptyStateView(
                systemImage: "sparkles",
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
            summarySection
            patternsSection
            suggestionsSection
            mixSection
        }
    }

    /// Bloques con un latido suave, nunca un spinner centrado que bloquee la
    /// hoja: lo que ya se sabe se sigue viendo.
    private var shimmer: some View {
        VStack(alignment: .leading, spacing: Space.p12.rawValue) {
            ForEach(0 ..< 3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Radius.inner.rawValue, style: .continuous)
                    .fill(lana.surface2)
                    .frame(height: LanaMetrics.minRowHeight)
            }
        }
        .opacity(0.7)
        .transition(.opacity)
        .accessibilityLabel("Leyendo \(model.anchorLabel)")
    }

    // MARK: - Resumen

    /// Dos frases como máximo, con las cifras en semibold. Si todo va
    /// destacado, nada destaca.
    @ViewBuilder
    private var summarySection: some View {
        if let summary = model.narrative?.summary, !summary.isEmpty {
            Text(summary)
                .lanaFont(.summary)
                .foregroundStyle(lana.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, Space.p10.rawValue)
        }
        Text(contextNote)
            .lanaFont(.detail)
            .foregroundStyle(lana.ink42)
            .padding(.bottom, Space.p26.rawValue)
    }

    /// La moneda se nombra siempre que haya más de una, y el procesamiento
    /// on-device se dice: es una razón para confiar en la app.
    private var contextNote: String {
        guard let currency = model.analyzedCurrency else { return "En tu teléfono" }
        guard !model.otherCurrencies.isEmpty else { return "Analizando \(currency.rawValue) · en tu teléfono" }
        let others = model.otherCurrencies.map(\.rawValue).joined(separator: ", ")
        return "Analizando \(currency.rawValue) · también tuviste movimientos en \(others)"
    }

    // MARK: - Lo que se repite, según el modelo

    @ViewBuilder
    private var patternsSection: some View {
        let patterns = model.narrative?.patterns ?? []
        if !patterns.isEmpty {
            SectionHeader("Lo que se repite", style: .minor)
                .padding(.bottom, Space.p12.rawValue)
            VStack(spacing: Space.p10.rawValue) {
                ForEach(patterns.prefix(3), id: \.self) { pattern in
                    LanaCard(padding: .p14, radius: .inner) {
                        Text(pattern)
                            .lanaFont(.explanation)
                            .foregroundStyle(lana.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.bottom, Space.p26.rawValue)
        }
    }

    /// Opción, nunca regaño: "podrías", "si quieres". Sin signos de admiración
    /// y sin emoji — el tono lo fija `NarrationInstructions`, aquí solo se
    /// presenta.
    @ViewBuilder
    private var suggestionsSection: some View {
        let ideas = model.narrative?.suggestions ?? []
        if !ideas.isEmpty || model.suggestion != nil {
            SectionHeader("Si quieres ajustar", style: .minor)
                .padding(.bottom, Space.p12.rawValue)
            VStack(spacing: Space.p10.rawValue) {
                ForEach(ideas.prefix(3), id: \.self) { idea in
                    suggestionCard { Text(idea).lanaFont(.explanation).foregroundStyle(lana.ink) }
                }
                if let suggestion = model.suggestion {
                    suggestionCard { ruleSuggestion(suggestion) }
                }
            }
            .padding(.bottom, Space.p28.rawValue)
        }
    }

    private func suggestionCard(@ViewBuilder content: () -> some View) -> some View {
        LanaCard(padding: .p14, radius: .inner, fill: .accent) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.inner.rawValue, style: .continuous)
                .strokeBorder(lana.accentBorder, lineWidth: LanaMetrics.hairline))
    }

    /// Lana propone una regla y recuerda la respuesta: descartarla no se
    /// vuelve a proponer.
    private func ruleSuggestion(_ suggestion: BudgetRuleRecommendation) -> some View {
        VStack(alignment: .leading, spacing: Space.sm.rawValue) {
            Text(suggestion.reason)
                .lanaFont(.explanation)
                .foregroundStyle(lana.ink)
            HStack(spacing: Space.p10.rawValue) {
                Button("Usarla") { model.selectRule(suggestion.rule) }
                    .buttonStyle(.lana(size: .compact))
                Button("Ahora no") { model.dismissSuggestion() }
                    .lanaFont(.footnote)
                    .foregroundStyle(lana.ink50)
                    .buttonStyle(.plain)
            }
            .frame(minHeight: LanaMetrics.minTouchTarget)
        }
    }

    // MARK: - Cómo repartiste

    @ViewBuilder
    private var mixSection: some View {
        if let mix = model.mix, let currency = model.analyzedCurrency {
            BudgetMixSection(
                mix: mix,
                shares: model.shares,
                currency: currency,
                selectedRule: model.selectedRule,
                onSelectRule: { model.selectRule($0) })

            Spacer()
                .frame(height: Space.p28.rawValue)
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

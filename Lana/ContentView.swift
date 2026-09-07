//
//  ContentView.swift
//  Lana
//

import CardsFeature
import DashboardFeature
import EntryFeature
import LanaCore
import LanaDesign
import OnboardingFeature
import SettingsFeature
import SharedFeature
import SwiftUI
import UIKit

/// La raíz de la app: arma `AppDependencies` (async por `CoreDataExpenseStore`)
/// y solo entonces decide entre el onboarding de primer arranque
/// (`OnboardingView`, con la `Guia_ApplePay`) y la navegación real
/// (`MainTabView`), según la bandera `hasCompletedOnboarding` en `UserDefaults`
/// (misma superficie de persistencia que el tema, Docs/DESIGN).
struct ContentView: View {
    let appDelegate: AppDelegate
    @State private var dependencies: AppDependencies?
    @State private var loadError: String?
    /// Se lee una vez de `UserDefaults` al construir y se voltea a `true` cuando
    /// el onboarding se confirma (`onOnboardingFinished`), lo que transiciona
    /// reactivamente a `MainTabView` (R6.3). `@State` en vez de leer
    /// `UserDefaults` en cada `body` para que el cambio dispare el redibujado.
    ///
    /// Arranca en `false` para cualquier instalación que no traiga la
    /// bandera — incluidas las que ya existían antes de que el onboarding
    /// existiera. Por eso `adoptOnboardingStateForExistingUser` lo corrige
    /// tras cargar los datos: ver ese método.
    @State private var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: Self.onboardingDefaultsKey)
    /// La misma clave que documenta el diseño (Docs/DESIGN → "Data Models").
    static let onboardingDefaultsKey = "lana.hasCompletedOnboarding"

    /// El entorno real de Apple Pay (task 7.1). `struct`, así que crearlo por
    /// valor donde se necesita no cuesta nada.
    private let environment = ApplePayEnvironmentProbe()

    var body: some View {
        Group {
            if let dependencies {
                if hasCompletedOnboarding {
                    MainTabView(dependencies: dependencies, environment: environment)
                } else {
                    OnboardingView(
                        model: OnboardingModel(onOnboardingFinished: finishOnboarding),
                        environment: environment,
                        onOpenCardSettings: { onboardingCardsModel = IdentifiedModel(dependencies.makeCardsModel()) },
                        onOpenShortcutsApp: { UIApplication.shared.openShortcutsApp() })
                        // La guía puede enlazar a "Ajustes → Tarjetas" (R3.4).
                        // Durante el onboarding no hay una pestaña de Tarjetas a
                        // la cual navegar, así que presentamos la superficie de
                        // gestión de tarjetas (`CardsView`) como hoja — el mismo
                        // patrón de closure cruzando fronteras de feature que
                        // `onExpenseTap` en `MainTabView`. Desde ahí el usuario
                        // agrega/edita el alias, últimos 4 y `walletMatchHint`.
                        .sheet(item: $onboardingCardsModel) { identified in
                            CardsView(model: identified.value, onExpenseTap: { _ in })
                        }
                }
            } else if let loadError {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "No se pudo iniciar", message: loadError)
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                let dependencies = try await AppDependencies.live()
                self.dependencies = dependencies
                // Conecta el store real para que `AppDelegate` pueda
                // aceptar invitaciones de `CKShare` (ADR-0020) — incluye
                // procesar cualquiera que haya llegado mientras esto cargaba.
                if let concreteExpenseStore = dependencies.concreteExpenseStore {
                    appDelegate.attach(store: concreteExpenseStore)
                }
                await adoptOnboardingStateForExistingUser(dependencies)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    /// La superficie de Tarjetas presentada como hoja durante el onboarding
    /// cuando la guía pide "Abrir Ajustes → Tarjetas" (R3.4). Vive aquí y no en
    /// `OnboardingFeature` porque solo el target de la app conoce `CardsFeature`
    /// — las features no se importan entre sí (Docs/ARCHITECTURE.md).
    /// Envuelto en `IdentifiedModel` porque `CardsModel` no es `Identifiable`
    /// y `.sheet(item:)` lo exige.
    @State private var onboardingCardsModel: IdentifiedModel<CardsModel>?

    /// Marca el onboarding como completo (R6.3) y transiciona a `MainTabView`
    /// volteando `hasCompletedOnboarding`. Corre en `MainActor` (lo llama el
    /// modelo de onboarding, que es `@MainActor`).
    ///
    /// - Returns: `true` si la bandera quedó fijada; `false` si por alguna razón
    ///   no pudo persistirse, para que la guía se mantenga en el cierre y ofrezca
    ///   "Reintentar" (R6.4).
    private func finishOnboarding() async -> Bool {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.onboardingDefaultsKey)
        // Verifica que la escritura sí se reflejó antes de transicionar — si no,
        // reporta el fallo al modelo en vez de dejar al usuario en un estado a
        // medias (R6.4).
        guard defaults.bool(forKey: Self.onboardingDefaultsKey) else { return false }
        hasCompletedOnboarding = true
        return true
    }

    /// Da el onboarding por visto en una instalación que ya venía usando
    /// Lana. `UserDefaults.bool(forKey:)` no distingue "false" de "nunca se
    /// escribió", así que sin esto **todo usuario existente** aterrizaría en
    /// la guía de Apple Pay en la primera actualización que la traiga, en vez
    /// de en su app — en la app cuyo principio es quitar fricción de la
    /// captura (Docs/CLAUDE.md).
    ///
    /// La señal de "ya venía usando Lana" es tener datos: una tarjeta dada de
    /// alta o un gasto registrado. Solo corre cuando la bandera nunca se
    /// escribió (`object(forKey:) == nil`), así que quien de verdad es nuevo
    /// sí ve el onboarding, y quien lo omitió no lo vuelve a ver.
    @MainActor
    private func adoptOnboardingStateForExistingUser(_ dependencies: AppDependencies) async {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.onboardingDefaultsKey) == nil else { return }
        guard await hasExistingData(dependencies) else { return }
        defaults.set(true, forKey: Self.onboardingDefaultsKey)
        hasCompletedOnboarding = true
    }

    /// Si el usuario ya tiene algo capturado. Ante un error de lectura
    /// responde `false`: mostrar el onboarding de más es molesto, pero
    /// saltárselo por un fallo transitorio dejaría a un usuario nuevo sin la
    /// guía y sin forma obvia de encontrarla.
    private func hasExistingData(_ dependencies: AppDependencies) async -> Bool {
        if let cards = try? await dependencies.cardStore.cards(), !cards.isEmpty {
            return true
        }
        guard let start = Calendar.current.date(byAdding: .year, value: -5, to: Date()) else { return false }
        let range = DateInterval(start: start, end: Date())
        let expenses = try? await dependencies.store.expenses(in: range)
        return !(expenses ?? []).isEmpty
    }
}

import Foundation
import LanaCore
import Testing
@testable import CardsFeature

/// La bandera que decide en qué volumen se presenta la entrada a la guía de
/// Apple Pay dentro de Tarjetas: invitación en degradado la primera vez, fila
/// discreta una vez recorrida. Nunca afirma que la captura automática esté
/// funcionando — Lana no puede verificarlo (ver `CardsModel`).
@Suite("CardsModel — guía de Apple Pay")
@MainActor
struct CardsModelApplePayGuideTests {
    /// Un `UserDefaults` aislado por test — `.standard` es global al proceso
    /// y filtraría estado entre corridas.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "CardsModelApplePayGuideTests.\(UUID().uuidString)"
        // swiftlint:disable:next force_unwrapping
        return UserDefaults(suiteName: suiteName)!
    }

    private func makeModel(userDefaults: UserDefaults) -> CardsModel {
        CardsModel(
            cardStore: InMemoryCardStore(),
            store: InMemoryExpenseStore(),
            cardPaymentStore: InMemoryCardPaymentStore(),
            userDefaults: userDefaults)
    }

    @Test("Sin nada guardado, la guía se da por no vista")
    func sinNadaGuardadoLaGuiaNoSeHaVisto() {
        #expect(!makeModel(userDefaults: makeDefaults()).hasSeenApplePayGuide)
    }

    @Test("Marcarla como vista persiste y sobrevive a un modelo nuevo")
    func marcarLaGuiaPersiste() {
        let defaults = makeDefaults()
        let model = makeModel(userDefaults: defaults)

        model.markApplePayGuideSeen()

        #expect(model.hasSeenApplePayGuide)
        // Un modelo nuevo sobre los mismos defaults es lo que pasa al
        // relanzar la app: la entrada tiene que seguir en su volumen bajo.
        #expect(makeModel(userDefaults: defaults).hasSeenApplePayGuide)
    }

    @Test("El target de la app puede marcarla por su clave pública")
    func laClavePublicaEsLaMisma() {
        let defaults = makeDefaults()
        // Así lo hace `ContentView` al terminar el onboarding, cuando todavía
        // no existe ningún `CardsModel` que marcar.
        defaults.set(true, forKey: CardsModel.applePayGuideSeenDefaultsKey)

        #expect(makeModel(userDefaults: defaults).hasSeenApplePayGuide)
    }
}

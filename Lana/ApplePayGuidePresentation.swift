import Foundation
import Observation
import OnboardingFeature
import UIKit

extension UIApplication {
    /// Abre la app Atajos (best-effort) vía su URL scheme. Su ausencia no rompe
    /// la guía — por eso no reporta error si no puede abrirse (Docs/DESIGN →
    /// "onOpenShortcutsApp… best-effort"). La usa `ContentView` tanto en
    /// onboarding como al reabrir la guía desde Ajustes (R1.4).
    func openShortcutsApp() {
        guard let url = URL(string: "shortcuts://") else { return }
        open(url)
    }
}

/// Envuelve un modelo de referencia no-`Identifiable` para poder presentarlo
/// con `.sheet(item:)`, que exige `Identifiable`. La identidad es de la
/// instancia (`ObjectIdentifier`), no del contenido — igual que el patrón que
/// varios modelos de las features resuelven con un `id = UUID()` propio, pero
/// aquí sin tener que tocar esos tipos (viven en features que no debemos
/// modificar por esta tarea).
struct IdentifiedModel<Value: AnyObject>: Identifiable {
    let value: Value
    var id: ObjectIdentifier {
        ObjectIdentifier(value)
    }

    init(_ value: Value) {
        self.value = value
    }
}

/// Puente entre el handler `onConfigureApplePay` que `SettingsModel` recibe en
/// `init` (cuando el `@State` de `MainTabView` aún no puede mutarse desde una
/// closure) y la presentación de la hoja de la guía en `Mode.standalone`
/// (R1.4). La closure fija `model` en este objeto de referencia; la vista lo
/// observa y presenta/cierra la hoja según ese valor.
@MainActor
@Observable
final class ApplePayGuidePresenter {
    var model: IdentifiedModel<GuiaApplePayModel>?
}

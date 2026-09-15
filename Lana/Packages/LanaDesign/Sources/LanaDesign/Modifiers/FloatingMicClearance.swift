import SwiftUI

public extension View {
    /// El colchón inferior que libra al contenido del micrófono flotante.
    ///
    /// `MainTabView` monta un botón de 76pt sobre CUALQUIER pestaña, así que
    /// el último elemento de un `ScrollView` queda tapado si la pantalla no
    /// deja este espacio. No es decoración: sin él hay filas que no se pueden
    /// leer ni tocar (la Versión en Ajustes, el CTA de Apple Pay al final de
    /// Tarjetas). Vive aquí —y no como un `.padding(.bottom, ...)` copiado en
    /// cada vista— para que agregar una pantalla nueva sea una línea y no un
    /// bug de recorte que solo se ve en el dispositivo.
    func floatingMicClearance() -> some View {
        padding(.bottom, Space.xxl.rawValue)
    }
}

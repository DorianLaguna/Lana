//
//  LanaCaptureLink.swift
//  LanaWidget
//

import Foundation

/// El único destino de todo lo que ofrece esta extensión: abrir Lana ya en
/// modo escucha (ADR-0018). El widget y el control lo comparten para que no
/// existan dos literales que puedan separarse con el tiempo.
enum LanaCaptureLink {
    /// `lana://capture` — la app lo atiende con `.onOpenURL` en `MainTabView`.
    static let url: URL = {
        guard let url = URL(string: "lana://capture") else {
            preconditionFailure("lana://capture es un literal fijo, siempre válido")
        }
        return url
    }()
}

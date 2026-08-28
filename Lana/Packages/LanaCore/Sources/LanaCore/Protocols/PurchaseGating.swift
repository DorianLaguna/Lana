/// El desbloqueo de la app: freemium con unlock único vía StoreKit 2
/// (Fase 10). El resto del sistema solo conoce este protocolo.
public protocol PurchaseGating: Sendable {
    var isUnlocked: Bool { get async }
    func purchase() async throws
    func restore() async throws
}

/// Implementación en memoria para tests y `#Preview`.
public actor InMemoryPurchaseGating: PurchaseGating {
    private var unlocked: Bool

    public init(isUnlocked: Bool = true) {
        unlocked = isUnlocked
    }

    public var isUnlocked: Bool {
        unlocked
    }

    public func purchase() async throws {
        unlocked = true
    }

    public func restore() async throws {
        unlocked = true
    }
}

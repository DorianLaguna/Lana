import Foundation

public enum PersistenceError: LocalizedError, Sendable {
    case noStoreDescription

    public var errorDescription: String? {
        switch self {
        case .noStoreDescription:
            "El contenedor de Core Data no tiene ninguna store description."
        }
    }
}

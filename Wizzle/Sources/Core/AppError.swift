import Foundation

// MARK: - Unified App-Level Error Type
enum AppError: Error, LocalizedError, Identifiable {
    // MARK: Cases
    case network(String)
    case decoding
    case unauthorized
    case notFound
    case storage(String)
    case unknown
    case custom(String)
    
    // MARK: - Localized Error
    var errorDescription: String? {
        switch self {
        case .network(let m): return m
        case .decoding:       return "Failed to decode server response."
        case .unauthorized:   return "Your session expired. Please sign in again."
        case .notFound:       return "Not found."
        case .storage(let m): return m
        case .unknown:        return "Something went wrong."
        case .custom(let m):  return m
        }
    }
    
    // MARK: - For SwiftUI Alerts / Sheets
    var id: String {localizedDescription}
    
    // MARK: - Convenience Factory
    static func wrap(_ error: Error) -> AppError {
        if let e = error as? AppError {
            return e
        } else {
            return .custom(error.localizedDescription)
        }
    }
}

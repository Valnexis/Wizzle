import Foundation

enum AppError: Error, LocalizedError {
    case network(String)
    case decoding
    case unauthorized
    case notFound
    case storage(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .network(let m): return m
        case .decoding:       return "Failed to decode server response."
        case .unauthorized:   return "Your session expired. Please sign in again."
        case .notFound:       return "Not found."
        case .storage(let m): return m
        case .unknown:        return "Something went wrong."
        }
    }
}

import Foundation

public enum Currency: Codable {
    case USD
    case EUR

    public var ticker: String {
        switch self {
        case .USD: return "USD"
        case .EUR: return "EUR"
        }
    }

    public var symbol: String {
        switch self {
        case .USD: return "$"
        case .EUR: return "€"
        }
    }
}
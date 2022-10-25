import Foundation

public struct SKFSubscription: Codable {
    public let planId: SKFBillingPlan.ID
    public let expiresIn: Expiration
    public let status: Status

    public init(
            planId: SKFBillingPlan.ID,
            expiresIn: Expiration,
            status: Status
    ) {
        self.planId = planId
        self.expiresIn = expiresIn
        self.status = status
    }
}

extension SKFSubscription {
    public enum Status: Codable {
        case undefined
        case expired
        case inBillingRetryPeriod
        case inGracePeriod
        case revoked
        case subscribed
    }

    public enum Expiration: Codable {
        case never
        case at(date: Date)

        public var date: Date {
            switch self {
            case .never: return .distantFuture
            case let .at(date): return date
            }
        }
    }
}
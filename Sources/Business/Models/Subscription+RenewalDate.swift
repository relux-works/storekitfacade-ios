import StoreKit

extension Product.SubscriptionInfo.RenewalState {
    public var asSubscriptionStatus: SKFSubscription.Status {
        switch self {
        case .expired: return .expired
        case .inBillingRetryPeriod: return .inBillingRetryPeriod
        case .inGracePeriod: return .inGracePeriod
        case .revoked: return .revoked
        case .subscribed: return .subscribed
        default: return .undefined
        }
    }
}
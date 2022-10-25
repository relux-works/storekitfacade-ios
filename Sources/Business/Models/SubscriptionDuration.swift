import Foundation
import StoreKit

extension SKFBillingPlan.BillingItem.Duration {
    static func from(_ productSubscription: Product.SubscriptionPeriod) -> Self {
        switch productSubscription.unit {
        case .day:
            return .day(productSubscription.value.asUInt)
        case .week:
            return .week(productSubscription.value.asUInt)
        case .month:
            return .month(productSubscription.value.asUInt)
        case .year:
            return .year(productSubscription.value.asUInt)
        @unknown default:
            return .undefined
        }
    }
}

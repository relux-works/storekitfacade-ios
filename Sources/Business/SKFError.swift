import Foundation
import StoreKit

public enum SKFError: Error {
    case failedToGetCurrentSubscription(cause: Error)
    case invalidProduct
    case failedToObtainAllProducts(cause: Error)
    case failedToPurchase(productId: String, cause: Error)
    case failedToVerifyMembershipBillingItems(cause: Error)
    case failedToStartRefund_noActiveSubscriptionFoundInGroup(group: [SKFBillingPlan])
    case failedToRefund_notSupportedStatus(status: Transaction.RefundRequestStatus)
    case failedToRefund_noCurrentWindowSceneFound
    case failedToRefund(cause: Error)

    public enum Cause: Error {
        case noProductFound
        case purchaseStatus(s: SKFPurchaseStatus)
    }
}
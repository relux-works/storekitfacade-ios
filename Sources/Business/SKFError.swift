import Foundation




public enum SKFError: Error {
    case failedToGetCurrentSubscription(cause: Error)
    case invalidProduct
    case failedToObtainAllProducts(cause: Error)
    case failedToPurchase(productId: String, cause: Error)
    case failedToVerifyMembershipBillingItems(cause: Error)

    public enum Cause: Error {
        case noProductFound
        case purchaseStatus(s: SKFPurchaseStatus)
    }
}
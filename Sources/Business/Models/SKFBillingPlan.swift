import Foundation

public struct SKFBillingPlan: Identifiable, Codable, Hashable, Equatable {
    public typealias ID = UUID
    public let id: ID
    public let label: String
    public let subscriptionKinds: [BillingItem]
    public let marketingInfo: MarketingInfo

    public init(
            id: ID,
            label: String,
            billingItems: [BillingItem],
            marketingInfo: MarketingInfo
    ) {
        self.id = id
        self.label = label
        self.subscriptionKinds = billingItems
        self.marketingInfo = marketingInfo
    }
}

extension SKFBillingPlan {
    public struct BillingItem: Codable, Hashable {
        public typealias ID = UUID
        public let id: ID
        public let planId: SKFBillingPlan.ID
        public let productId: String
        public let duration: Duration
        public let info: Info

        public init(
                id: ID,
                planId: SKFBillingPlan.ID,
                productId: String,
                duration: Duration,
                info: Info
        ) {
            self.id = id
            self.planId = planId
            self.productId = productId
            self.duration = duration
            self.info = info
        }
    }
}

extension SKFBillingPlan.BillingItem {
    public enum Duration: Codable, Hashable {
        case undefined
        case unlimited
        case day(UInt)
        case week(UInt)
        case month(UInt)
        case year(UInt)
    }

    public struct Info: Codable, Hashable  {
        public let displayName: String
        public let description: String
        public let displayPrice: String
        public let price: Decimal

        public init(
                displayName: String,
                description: String,
                displayPrice: String,
                price: Decimal
        ) {
            self.displayName = displayName
            self.description = description
            self.displayPrice = displayPrice
            self.price = price
        }
    }

}

extension SKFBillingPlan {
    public struct MarketingInfo: Codable, Hashable {
        public let title: String
        public let description: String

        public init(
                title: String,
                description: String
        ) {
            self.title = title
            self.description = description
        }
    }

}


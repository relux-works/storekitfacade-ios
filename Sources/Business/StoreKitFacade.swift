import StoreKit
import Combine


public protocol IStoreKitFacade {
var transactionsStateChangePub: AnyPublisher<Void, Never> { get }
    @available(iOS 16, *)
    var messageStateChangePub: AnyPublisher<StoreKit.Message, Never> { get }

    var subscriptionStatusChangePub: AnyPublisher<Product.SubscriptionInfo.Status, Never> { get }

    func presentCodeRedemptionSheet()
    func presentRefundSheet(for subscriptionGroup: [SKFBillingPlan]) async throws

    func purchase(billingItem: SKFBillingPlan.BillingItem) async -> Result<Void, SKFError>
    func getActiveRenewableSubscription(for availablePlans: [SKFBillingPlan]) async throws -> SKFSubscription?
    func verifyAvailableRenewableSubscriptions(for availablePlans: [SKFBillingPlan]) async -> Result<[SKFBillingPlan], SKFError>
}

public class StoreKitFacade: IStoreKitFacade {
    private var transactionsListenerTask: Task<Void, Error>? = nil
    private var messageListenerTask: Task<Void, Error>? = nil
    private var subscriptionStatusListenerTask: Task<Void, Error>? = nil

    private var pipelines: Set<AnyCancellable> = []

    private var skTransactionCoordinator: SKFTransactionObserver

    private let transactionsStateChangeSub: PassthroughSubject<Void, Never> = .init()
    public var transactionsStateChangePub: AnyPublisher<Void, Never> { transactionsStateChangeSub.eraseToAnyPublisher() }

    private var messageStateChangeSub: PassthroughSubject<Any, Never> = .init()

    @available(iOS 16, *)
    public var messageStateChangePub: AnyPublisher<StoreKit.Message, Never> {
        messageStateChangeSub
                .compactMap { $0 as? StoreKit.Message }
                .eraseToAnyPublisher()
    }

    private let subscriptionStatusChangeSub: PassthroughSubject<Product.SubscriptionInfo.Status, Never> = .init()
    public var subscriptionStatusChangePub: AnyPublisher<Product.SubscriptionInfo.Status, Never> { subscriptionStatusChangeSub.eraseToAnyPublisher() }

    public init() {
        skTransactionCoordinator = .init()
        skTransactionCoordinator.transactionsStateChangePub
                .sink { [weak self] in self?.transactionsStateChangeSub.send(()) }
                .store(in: &pipelines)
        transactionsListenerTask = listenForTransactions()
        if #available(iOS 16, *) { messageListenerTask = listenForMessages() }
        subscriptionStatusListenerTask = listenForSubscriptionStatusChange()
        transactionsStateChangeSub.send()
    }

    deinit {
        transactionsListenerTask?.cancel()
        messageListenerTask?.cancel()
        subscriptionStatusListenerTask?.cancel()
    }

    public func presentCodeRedemptionSheet() {
        DispatchQueue.main.async {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
    }

    public func presentRefundSheet(for subscriptionGroup: [SKFBillingPlan]) async throws {
        do {
            guard let windowScene = ( await UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first ) else {
                throw SKFError.failedToRefund_noCurrentWindowSceneFound
            }

            let transactionIds = await getCurrentEntitlements()
                    .filter( { $0.productType.contained(in: [.autoRenewable])})
                    .map { $0.productID }

            let billingItems: [SKFBillingPlan.BillingItem] = subscriptionGroup.flatMap {$0.subscriptionKinds }

            let currentMembershipInGroup = try await getStoreProducts(for: billingItems)
                    .filter { $0.type.contained(in: [.autoRenewable]) }
                    .filter { $0.id.contained(in: transactionIds)}
                    .first

            guard let resultToVerify = await currentMembershipInGroup?.latestTransaction else {
                throw SKFError.failedToStartRefund_noActiveSubscriptionFoundInGroup(group: subscriptionGroup)
            }

            let transaction = try checkVerified(resultToVerify)
            let status = try await StoreKit.Transaction.beginRefundRequest(for: transaction.id, in: windowScene)
            switch status {
            case .userCancelled:
                return
            case .success:
                return
            default:
                throw SKFError.failedToRefund_notSupportedStatus(status: status)
            }
        } catch {
            throw SKFError.failedToRefund(cause: error)
        }
    }

    public func purchase(billingItem: SKFBillingPlan.BillingItem) async -> Result<Void, SKFError> {
        do {
            let product = try await getStoreProducts(for: [billingItem]).first

            guard let product = product else {
                return .failure(.failedToPurchase(productId: billingItem.productId, cause: SKFError.Cause.noProductFound))
            }

            let status = try await purchase(product)

            switch status {
            case .purchased:
                transactionsStateChangeSub.send()
                return .success(())
            default:
                return .failure(.failedToPurchase(productId: billingItem.productId, cause: SKFError.Cause.purchaseStatus(s: status)))
            }
        } catch {
            return .failure(.failedToPurchase(productId: billingItem.productId, cause: error))
        }
    }

    public func getActiveRenewableSubscription(for availablePlans: [SKFBillingPlan]) async throws -> SKFSubscription? {
        let transactionIds = await getCurrentEntitlements()
                .filter( { $0.productType.contained(in: [.autoRenewable])})
                .map { $0.productID }

        let billingItems: [SKFBillingPlan.BillingItem] = availablePlans.flatMap {$0.subscriptionKinds }

        let membership = try await getStoreProducts(for: billingItems)
                .filter { $0.type.contained(in: [.autoRenewable]) }
                .filter { $0.id.contained(in: transactionIds)}
                .first

        let status = try await membership?.subscription?.status.first?.state

        guard let membership = membership,
              let subscription = membership.subscription,
              let status = status,
              let billingItem = (billingItems.first { $0.productId == membership.id })
        else { return nil }
        //crashes app in ios 15
        //print(">>> \(subscription.subscriptionPeriod.dateRange(referenceDate: .now))")
        return .init(
                planId: billingItem.planId,
                expiresIn: .at(date: .distantFuture),
                status: status.asSubscriptionStatus
        )
    }

    public func verifyAvailableRenewableSubscriptions(for availablePlans: [SKFBillingPlan]) async -> Result<[SKFBillingPlan], SKFError> {
        do {
            let allProducts = try await getStoreProducts(for: availablePlans.flatMap {$0.subscriptionKinds})
            let plans: [SKFBillingPlan] = availablePlans
                    .map {
                        .init(
                                id: $0.id,
                                label: $0.label,
                                billingItems: $0.subscriptionKinds
                                        .compactMap { buildMembershipBillingItem(billingItem: $0, allProducts: allProducts) },
                                marketingInfo: $0.marketingInfo
                        )
                    }
                    .filter { $0.subscriptionKinds.isNotEmpty }
            return .success(plans)
        } catch {
            return .failure(.failedToVerifyMembershipBillingItems(cause: error))
        }
    }

    private func getCurrentEntitlements() async -> [Transaction] {
        var validTransactions: [Transaction] = []
        //Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction: Transaction = try checkVerified(result)
                validTransactions.append(transaction)
            } catch {
                print("INVALID TRANSACTION")
            }
        }

        return validTransactions
    }

    private func getStoreProducts(for billingItems: [SKFBillingPlan.BillingItem]) async throws -> [Product] {
        try await Product
                .products(for: billingItems.map {$0.productId})
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SKFError.invalidProduct
        case .verified(let payload): return payload
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await transaction?.finish()
                    self?.transactionsStateChangeSub.send()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }

    @available(iOS 16, *)
    private func listenForMessages() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await msg in StoreKit.Message.messages {
                self?.messageStateChangeSub.send(msg)
            }
        }
    }

    private func listenForSubscriptionStatusChange() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await status in Product.SubscriptionInfo.Status.updates {
// todo: deal with payment increase statuses

//                let payload = try? status.renewalInfo.payloadValue
//                payload?.priceIncreaseStatus == .agreed
//                payload?.expirationReason == .didNotConsentToPriceIncrease
//                payload?.willAutoRenew

                guard let transaction = try self?.checkVerified(status.transaction) else { continue }
                await transaction.finish()

                self?.subscriptionStatusChangeSub.send(status)
            }
        }
    }

    private func purchase(_ product: Product) async throws -> SKFPurchaseStatus {
        switch  try await product.purchase() {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return .purchased
        case .userCancelled:
            return .userCanceled
        case .pending:
            return .pending
        default:
            return .undefined
        }
    }
}

private class SKFTransactionObserver: NSObject, SKPaymentTransactionObserver {
    private let transactionsStateChangeSub: PassthroughSubject<Void, Never> = .init()
    public var transactionsStateChangePub: AnyPublisher<Void, Never> { transactionsStateChangeSub.eraseToAnyPublisher() }

    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    deinit {
        SKPaymentQueue.default().remove(self)
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        transactions
            .forEach { t in
                switch t.transactionState {
                case .purchased,
                     .failed,
                     .restored:
                    SKPaymentQueue.default().finishTransaction(t)
                case .purchasing:
                    break
                case .deferred:
                    break
                @unknown default:
                    break
                }
            }

        transactionsStateChangeSub.send(())
    }
}

extension StoreKitFacade {
    private func buildMembershipBillingItem(billingItem: SKFBillingPlan.BillingItem, allProducts: [Product]) -> SKFBillingPlan.BillingItem? {
        guard let product = (allProducts.first { $0.id == billingItem.productId }) ,
              product.type == .autoRenewable,
              let subscription = product.subscription
        else { return nil }

        return .init(
                id: billingItem.id,
                planId: billingItem.planId,
                productId: product.id,
                duration: SKFBillingPlan.BillingItem.Duration.from(subscription.subscriptionPeriod),
                info: .init(
                        displayName: product.displayName,
                        description: product.description,
                        displayPrice: product.displayPrice
                )
        )
    }
}

import Flutter
import StoreKit

@available(iOS 15.0, *)
class BillingIssueHandler {

    func checkBillingIssue(result: @escaping FlutterResult) {
        Task {
            var billingState = "normal"
            var gracePeriodExpiresAt: Int64? = nil

            do {
                for await verificationResult in Transaction.currentEntitlements {
                    guard case .verified(let transaction) = verificationResult else { continue }
                    guard let groupID = transaction.subscriptionGroupID else { continue }

                    let statuses = try await Product.SubscriptionInfo.status(for: groupID)
                    for status in statuses {
                        guard case .verified(_) = status.renewalInfo else { continue }

                        switch status.state {
                        case .inGracePeriod:
                            billingState = "inGracePeriod"
                            if case .verified(let tx) = status.transaction,
                               let expirationDate = tx.expirationDate {
                                gracePeriodExpiresAt = Int64(expirationDate.timeIntervalSince1970 * 1000)
                            }
                        case .inBillingRetryPeriod:
                            // Only upgrade to billingRetry if not already in grace period
                            if billingState != "inGracePeriod" {
                                billingState = "inBillingRetryPeriod"
                            }
                        case .revoked:
                            if billingState == "normal" {
                                billingState = "revoked"
                            }
                        case .expired:
                            if billingState == "normal" {
                                billingState = "expired"
                            }
                        default:
                            break
                        }
                    }
                }
            } catch {
                result([
                    "state": "normal",
                    "managementURL": "https://apps.apple.com/account/subscriptions",
                ] as [String: Any])
                return
            }

            var response: [String: Any] = [
                "state": billingState,
                "managementURL": "https://apps.apple.com/account/subscriptions",
            ]

            if let expiresAt = gracePeriodExpiresAt {
                response["gracePeriodExpiresAt"] = expiresAt
            }

            result(response)
        }
    }
}

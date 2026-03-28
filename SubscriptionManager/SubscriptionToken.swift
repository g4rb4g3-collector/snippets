import Foundation

struct SubscriptionToken {
    let id: UUID
    let subscriptionId: String

    init(subscriptionId: String) {
        self.id = UUID()
        self.subscriptionId = subscriptionId
    }
}

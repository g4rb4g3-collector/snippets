import Foundation

struct Subscription: Hashable {
    let id: String
    let types: [SubscriptionType]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
        lhs.id == rhs.id
    }
}

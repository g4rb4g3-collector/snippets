import Foundation

enum SubscriptionEvent {
    case subscribed(id: String, types: [SubscriptionType])
    case unsubscribed(id: String, types: [SubscriptionType])
}

typealias SubscriptionCallback = (SubscriptionEvent) -> Void

import Foundation

enum SubscriptionEvent {
    case subscribed(id: String, types: [SubscriptionType], allTypes: [SubscriptionType])
    case unsubscribed(id: String, types: [SubscriptionType], remainingTypes: [SubscriptionType])
}

typealias SubscriptionCallback = (SubscriptionEvent) -> Void

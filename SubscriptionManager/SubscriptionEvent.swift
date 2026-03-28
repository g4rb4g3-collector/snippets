import Foundation

enum SubscriptionEvent {
    case subscribed(Subscription)
    case unsubscribed(Subscription)
}

typealias SubscriptionCallback = (SubscriptionEvent) -> Void

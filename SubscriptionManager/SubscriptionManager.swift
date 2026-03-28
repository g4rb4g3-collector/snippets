import Foundation

enum SubscriptionType: String, Codable, CaseIterable {
    case m1
    case m5
    case m15
    case h1
}

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

enum SubscriptionEvent {
    case subscribed(Subscription)
    case unsubscribed(Subscription)
}

typealias SubscriptionCallback = (SubscriptionEvent) -> Void

final class SubscriptionManager {
    private var subscriptions: Set<Subscription> = []
    private var callbacks: [SubscriptionCallback] = []
    private let queue = DispatchQueue(label: "com.subscriptionmanager.sync")

    func onChanged(_ callback: @escaping SubscriptionCallback) {
        queue.sync {
            callbacks.append(callback)
        }
    }

    func subscribe(_ subscription: Subscription) {
        queue.sync {
            subscriptions.insert(subscription)
        }
        notifyAll(.subscribed(subscription))
    }

    func unsubscribe(_ subscription: Subscription) {
        queue.sync {
            subscriptions.remove(subscription)
        }
        notifyAll(.unsubscribed(subscription))
    }

    func getActiveSubscriptions() -> Set<Subscription> {
        queue.sync { subscriptions }
    }

    func isSubscribed(_ id: String) -> Bool {
        queue.sync { subscriptions.contains(where: { $0.id == id }) }
    }

    private func notifyAll(_ event: SubscriptionEvent) {
        let cbs = queue.sync { callbacks }
        for cb in cbs {
            cb(event)
        }
    }
}

import Foundation

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
        let removed = queue.sync { subscriptions.remove(subscription) }
        if removed != nil {
            notifyAll(.unsubscribed(subscription))
        }
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

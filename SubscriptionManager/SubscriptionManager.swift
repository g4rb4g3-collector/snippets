import Foundation

final class SubscriptionManager {
    private var registrations: [UUID: Subscription] = [:]
    private var callbacks: [SubscriptionCallback] = []
    private let queue = DispatchQueue(label: "com.subscriptionmanager.sync")

    func onChanged(_ callback: @escaping SubscriptionCallback) {
        queue.sync {
            callbacks.append(callback)
        }
    }

    @discardableResult
    func subscribe(_ subscription: Subscription) -> SubscriptionToken {
        let token = SubscriptionToken(subscriptionId: subscription.id)
        let (addedTypes, allTypes): ([SubscriptionType], [SubscriptionType]) = queue.sync {
            let before = activeTypes(for: subscription.id)
            registrations[token.id] = subscription
            let after = activeTypes(for: subscription.id)
            return (after.filter { !before.contains($0) }, Array(after))
        }
        if !addedTypes.isEmpty {
            notifyAll(.subscribed(id: subscription.id, types: addedTypes, allTypes: allTypes))
        }
        return token
    }

    func unsubscribe(_ token: SubscriptionToken) {
        let (removedTypes, remainingTypes): ([SubscriptionType], [SubscriptionType]) = queue.sync {
            guard registrations[token.id] != nil else { return ([], []) }
            let before = activeTypes(for: token.subscriptionId)
            registrations.removeValue(forKey: token.id)
            let after = activeTypes(for: token.subscriptionId)
            return (before.filter { !after.contains($0) }, Array(after))
        }
        if !removedTypes.isEmpty {
            notifyAll(.unsubscribed(id: token.subscriptionId, types: removedTypes, remainingTypes: remainingTypes))
        }
    }

    func getActiveTypes(for id: String) -> Set<SubscriptionType> {
        queue.sync { activeTypes(for: id) }
    }

    private func activeTypes(for id: String) -> Set<SubscriptionType> {
        var result = Set<SubscriptionType>()
        for (_, reg) in registrations where reg.id == id {
            result.formUnion(reg.types)
        }
        return result
    }

    private func notifyAll(_ event: SubscriptionEvent) {
        let cbs = queue.sync { callbacks }
        for cb in cbs {
            cb(event)
        }
    }
}

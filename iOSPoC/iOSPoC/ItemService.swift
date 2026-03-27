import Foundation

class ItemService {

    func getItem() -> Item {
        Item(name: generateName(), values: generateValues())
    }

    func getItems(count: Int = 20) -> [Item] {
        (0..<count).map { _ in getItem() }
    }

    // MARK: - Private

    private func generateName() -> String {
        let pool = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in pool.randomElement()! })
    }

    private func generateValues() -> [Double] {
        var values: [Double] = []
        var current = Double.random(in: 10...100)
        values.append(current)

        for _ in 1..<50 {
            let maxDelta = current * 0.005
            let lower = max(10.0, current - maxDelta)
            let upper = min(100.0, current + maxDelta)
            current = Double.random(in: lower...upper)
            values.append(current)
        }

        return values
    }
}

import SwiftUI
import Charts

struct ListView: View {
    private let items = ItemService().getItems()

    var body: some View {
        NavigationStack {
            List(items, id: \.name) { item in
                ItemRow(item: item)
            }
            .navigationTitle("List")
        }
    }
}

// MARK: - ItemRow

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack {
            Text(item.name)
                .font(.system(.body, design: .monospaced))

            Spacer()

            Chart {
                ForEach(Array(item.values.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(width: 80, height: 36)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ListView()
}

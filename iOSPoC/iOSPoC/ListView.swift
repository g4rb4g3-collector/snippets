import SwiftUI
import Charts

struct ListView: View {
    private let items = ItemService().getItems()
    @State private var expandedName: String?

    var body: some View {
        NavigationStack {
            List(items, id: \.name) { item in
                ItemRow(item: item, isExpanded: expandedName == item.name)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expandedName = expandedName == item.name ? nil : item.name
                        }
                    }
            }
            .navigationTitle("List")
        }
    }
}

// MARK: - ItemRow

private struct ItemRow: View {
    let item: Item
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                .chartYScale(domain: (item.values.min() ?? 0)...(item.values.max() ?? 100))
                .frame(width: 80, height: 36)
            }
            .padding(.vertical, 4)

            if isExpanded {
                ItemDetailView(item: item)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    ListView()
}

import SwiftUI

struct ListView: View {
    private let items = ItemService().getItems()
    @State private var expandedName: String?

    var body: some View {
        NavigationStack {
            List(items, id: \.name) { item in
                ItemRow(item: item, isExpanded: expandedName == item.name)
                    .listRowBackground(Color.warmSecondaryBackground)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expandedName = expandedName == item.name ? nil : item.name
                        }
                    }
            }
            .scrollContentBackground(.hidden)
            .background(Color.warmBackground)
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
                    .foregroundStyle(Color.warmPrimaryText)

                Spacer()

                SparklineView(values: item.values)
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

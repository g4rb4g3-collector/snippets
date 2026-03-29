import SwiftUI

struct ItemDetailView: View {
    let item: Item

    var body: some View {
        Text("details for \(item.name)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}

#Preview {
    ItemDetailView(item: Item(name: "abc12345", values: []))
}

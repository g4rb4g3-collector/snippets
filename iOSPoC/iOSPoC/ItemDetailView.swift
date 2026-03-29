import SwiftUI

struct ItemDetailView: View {
    let item: Item

    var body: some View {
        TabView {
            ForEach(1...3, id: \.self) { part in
                Text("details for \(item.name), part \(part)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 80)
    }
}

#Preview {
    ItemDetailView(item: Item(name: "abc12345", values: []))
}

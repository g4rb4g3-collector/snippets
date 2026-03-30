import SwiftUI
import MiniChart

struct ItemDetailView: View {
    let item: Item

    var body: some View {
        TabView {
            MiniChartView(
                data: item.values,
                lineColor: .warmAccent,
                indicatorColor: .warmSecondaryText
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ForEach(2...3, id: \.self) { part in
                Text("details for \(item.name), part \(part)")
                    .font(.subheadline)
                    .foregroundStyle(Color.warmSecondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 120)
    }
}

#Preview {
    ItemDetailView(item: Item(name: "abc12345", values: (0..<50).map { _ in Double.random(in: 10...100) }))
        .background(Color.warmSecondaryBackground)
}

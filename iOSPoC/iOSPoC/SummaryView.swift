import SwiftUI

struct SummaryView: View {
    var body: some View {
        ZStack {
            Color.warmBackground.ignoresSafeArea()
            Text("Summary")
                .foregroundStyle(Color.warmPrimaryText)
        }
    }
}

#Preview {
    SummaryView()
}

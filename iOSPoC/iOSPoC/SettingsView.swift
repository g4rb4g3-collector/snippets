import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            Color.warmBackground.ignoresSafeArea()
            Text("Settings")
                .foregroundStyle(Color.warmPrimaryText)
        }
    }
}

#Preview {
    SettingsView()
}

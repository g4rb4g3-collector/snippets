import SwiftUI

extension Color {
    // Backgrounds
    static let warmBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.09, blue: 0.07, alpha: 1)  // deep warm brown
            : UIColor(red: 0.98, green: 0.96, blue: 0.93, alpha: 1)  // cream
    })

    static let warmSecondaryBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.14, blue: 0.10, alpha: 1)
            : UIColor(red: 0.92, green: 0.89, blue: 0.85, alpha: 1)
    })

    // Text
    static let warmPrimaryText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.91, blue: 0.85, alpha: 1)
            : UIColor(red: 0.13, green: 0.10, blue: 0.07, alpha: 1)
    })

    static let warmSecondaryText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.60, green: 0.53, blue: 0.45, alpha: 1)
            : UIColor(red: 0.45, green: 0.37, blue: 0.29, alpha: 1)
    })

    // Accent — Claude-ish warm orange
    static let warmAccent = Color(red: 0.87, green: 0.46, blue: 0.25)
}

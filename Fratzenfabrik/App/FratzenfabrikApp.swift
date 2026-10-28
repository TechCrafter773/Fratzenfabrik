import SwiftUI

@main
struct FratzenfabrikApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Spook.slime)
        }
    }
}

/// Öffnet den Spuk-Spiegel mit einem bestimmten Design.
struct MirrorLaunch: Identifiable {
    let id = UUID()
    let design: DesignID
    var stepMode = false
}

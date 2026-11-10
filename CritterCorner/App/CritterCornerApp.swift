import SwiftUI

@main
struct CritterCornerApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "sv_SE"))
        }
    }
}

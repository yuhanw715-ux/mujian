import SwiftUI

@main
@MainActor
struct MujianApp: App {
    @StateObject private var store = DiaryStore()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(store).tint(store.library.appearance.accent.color)
                .environment(\.miuAccent, store.library.appearance.accent.color)
                .preferredColorScheme(store.library.appearance.mode.colorScheme)
                .environment(\.locale, Locale(identifier: "zh_CN"))
        }
    }
}

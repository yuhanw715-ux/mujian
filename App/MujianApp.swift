import SwiftUI

@main
@MainActor
struct MujianApp: App {
    @StateObject private var store = DiaryStore()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(store).tint(MiuTheme.lavender)
                .environment(\.locale, Locale(identifier: "zh_CN"))
        }
    }
}

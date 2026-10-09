import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CalendarAppearance()
    @State private var loaded = false
    @State private var issue: AlertMessage?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        CalendarBackdrop(preview: draft)
                        VStack(spacing: 12) {
                            Image(systemName: draft.mode == .light ? "sun.max" : "moon.stars").font(.largeTitle)
                            Text("让暮笺，换一种心情。").font(.headline)
                            Text("小暮暮写的 · Miu写的").font(.caption).foregroundStyle(.secondary)
                        }.padding(24).modifier(GlassSurface()).padding(24)
                    }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 22)).listRowInsets(EdgeInsets())
                }
                Section("明暗主题") {
                    Picker("明暗主题", selection: $draft.mode) {
                        ForEach(ThemeMode.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("强调色") {
                    HStack(spacing: 8) {
                        ForEach(AccentPalette.allCases) { palette in
                            Button { draft.accent = palette } label: {
                                VStack(spacing: 8) {
                                    Circle().fill(palette.color).frame(width: 34, height: 34)
                                        .overlay { if draft.accent == palette { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) } }
                                    Text(palette.label).font(.caption).foregroundStyle(.primary)
                                }.frame(maxWidth: .infinity).padding(.vertical, 6)
                            }.buttonStyle(.plain).accessibilityAddTraits(draft.accent == palette ? .isSelected : [])
                        }
                    }
                }
                Section {
                    Toggle("暗夜的小猫爪", isOn: $draft.nightPaws)
                } header: { Text("小装饰") } footer: { Text("猫爪在暗夜月历和日记栏的侧边轻轻向上浮动。开启“减弱动态效果”时会静止，也可以在这里关闭。") }
                Section {
                    Text("小暮暮当日写下的用暮紫，后来补写的用青色，尚未选择的用灰色；Miu 用粉色。强调色只改变按钮、选中态和装饰，不改变日记标记的含义。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("主题与颜色").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            var next = store.library.appearance
                            next.mode = draft.mode; next.accent = draft.accent; next.nightPaws = draft.nightPaws
                            do { try store.setAppearance(next); dismiss() }
                            catch { issue = AlertMessage(text: error.localizedDescription) }
                        }
                    }
                }
        }.tint(draft.accent.color).environment(\.miuAccent, draft.accent.color)
            .preferredColorScheme(draft.mode.colorScheme)
            .onAppear { if !loaded { draft = store.library.appearance; loaded = true } }
            .alert(item: $issue) { item in Alert(title: Text("设置还没保存好"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
}

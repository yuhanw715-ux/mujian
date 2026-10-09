import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var appearance = false
    @State private var themeSettings = false
    @State private var calendarArt = false
    @State private var drafts = false
    @State private var trash = false
    @State private var fontSize = 18.0
    @State private var exporting = false
    @State private var exportDocument: DiaryFileDocument?
    @State private var exportName = "暮笺备份.json"
    @State private var importing = false
    @State private var backup: DiaryBackup?
    @State private var restorePreview = false
    @State private var busy = false
    @State private var issue: AlertMessage?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Image("BrandIcon").resizable().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 15))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("暮笺").font(.title2.weight(.semibold))
                            Text("和 Miu，一天一页。").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 10)
                }
                Section("月历的模样") {
                    Button { themeSettings = true } label: { Label("主题与颜色", systemImage: "paintpalette") }
                    Button { calendarArt = true } label: { Label("月历背景与图片", systemImage: "square.3.layers.3d") }
                }.disabled(store.isReadOnly)
                if let loadIssue = store.loadIssue {
                    Section("本地文件需要照看一下") {
                        Text(loadIssue).font(.footnote)
                        Button("导出保留的原文件") { exportOriginal() }
                    }
                }
                Section {
                    Button { appearance = true } label: { Label("单日页面的默认背景", systemImage: "photo") }
                    HStack {
                        Text("阅读字号")
                        Spacer()
                        Text("\(Int(fontSize))").foregroundStyle(.secondary).monospacedDigit()
                    }
                    Slider(value: $fontSize, in: 14...30, step: 1) { editing in
                        if !editing { do { try store.setFontSize(fontSize) } catch { issue = AlertMessage(text: error.localizedDescription) } }
                    }.accessibilityLabel("阅读字号")
                } header: { Text("读起来舒服一点") } footer: { Text("单日默认背景用于未单独设置的日期；月历背景在上方单独设置。") }
                .disabled(store.isReadOnly)
                Section("我的小抽屉") {
                    Button { drafts = true } label: { Label("草稿箱 · \(store.drafts.count)", systemImage: "pencil.and.outline") }
                    Button { trash = true } label: { Label("回收站", systemImage: "trash") }
                }.disabled(store.isReadOnly)
                Section {
                    Button { exportBackup() } label: { Label("导出完整备份", systemImage: "square.and.arrow.up") }.disabled(store.isReadOnly || busy)
                    Button { importing = true } label: { Label("从备份恢复", systemImage: "square.and.arrow.down") }.disabled(busy)
                    if busy { HStack { ProgressView(); Text("Miu 正在整理，请稍等…").font(.footnote) } }
                } header: { Text("好好保管这些日子") } footer: {
                    Text("日记、草稿和自定义背景只保存在本机。换设备或卸载前，请先把完整备份存到“文件”中。备份是可读取的文件，请放在你信任的位置。恢复时会合并不同日记，相同编号保留更新时间较新的一份。")
                }
                Section {
                    Text("“Miu写的”是日记分类，用来收藏 Miu 的文字；暮笺不会自动生成日记，也不会上传内容。")
                        .font(.footnote).foregroundStyle(.secondary)
                    HStack { Text("版本"); Spacer(); Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.0").foregroundStyle(.secondary) }
                }
            }.navigationTitle("暮笺的小设置").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .onAppear { fontSize = store.library.readerFontSize }
        .sheet(isPresented: $appearance) { AppearanceView(day: nil) }
        .sheet(isPresented: $themeSettings) { ThemeSettingsView() }
        .sheet(isPresented: $calendarArt) { CalendarArtEditor() }
        .sheet(isPresented: $drafts) { DraftsView() }
        .sheet(isPresented: $trash) { TrashView() }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: exportName) { result in
            if case .failure(let error) = result { issue = AlertMessage(text: error.localizedDescription) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                backup = try DiaryRules.decodeBackup(LocalFiles.read(url, limit: DiaryRules.maxBackupBytes))
                restorePreview = true
            } catch { issue = AlertMessage(text: "备份没有导入。\n" + error.localizedDescription) }
        }
        .sheet(isPresented: $restorePreview) {
            if let backup { RestorePreviewView(backup: backup) { fontSize = store.library.readerFontSize } }
        }
        .alert(item: $issue) { item in Alert(title: Text("Miu 的小提示"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
    private func exportBackup() {
        busy = true
        Task { @MainActor in
            await Task.yield()
            defer { busy = false }
            do {
                exportDocument = DiaryFileDocument(data: try store.backupData())
                exportName = "暮笺备份-\(DayKey.make(Date())).json"
                exporting = true
            } catch { issue = AlertMessage(text: error.localizedDescription) }
        }
    }
    private func exportOriginal() {
        do {
            exportDocument = DiaryFileDocument(data: try store.originalData())
            exportName = "暮笺原文件-\(DayKey.make(Date())).json"; exporting = true
        } catch { issue = AlertMessage(text: error.localizedDescription) }
    }
}

struct RestorePreviewView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    let backup: DiaryBackup
    let restored: () -> Void
    @State private var issue: AlertMessage?
    @State private var busy = false
    var body: some View {
        NavigationStack {
            Form {
                Section("这份备份里有") {
                    LabeledContent("日记", value: "\(backup.library.activeEntries.count) 篇")
                    LabeledContent("草稿", value: "\(backup.drafts.count) 篇")
                    LabeledContent("自定义背景", value: "\(backup.images.count) 张")
                    LabeledContent("回收站", value: "\(backup.library.entries.filter { $0.deletedAt != nil }.count) 篇")
                    LabeledContent("导出时间", value: backup.exportedAt.formatted(date: .abbreviated, time: .shortened))
                }
                Section {
                    Text("不同编号的日记会合并；相同编号保留较新的一份，包括移入回收站的状态。本机已有的背景设置会优先保留。")
                        .font(.subheadline)
                    Text("如果这里还是一本空日记，会同时恢复备份中的默认背景和字号。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button {
                        busy = true
                        Task { @MainActor in
                            await Task.yield()
                            do { try store.restore(backup); restored(); dismiss() }
                            catch { issue = AlertMessage(text: error.localizedDescription) }
                            busy = false
                        }
                    } label: {
                        HStack { Spacer(); if busy { ProgressView() }; Text(busy ? "正在恢复…" : "确认恢复"); Spacer() }
                    }.disabled(busy)
                }
            }.navigationTitle("先核对一下备份").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy)
            .alert(item: $issue) { item in Alert(title: Text("暂时没有恢复好"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
}

struct AppearanceView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    let day: String?
    @State private var style = BackgroundStyle()
    @State private var photo: PhotosPickerItem?
    @State private var issue: AlertMessage?
    @State private var loading = false
    @State private var loaded = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        DayBackground(day: day, preview: style)
                        VStack(alignment: .leading, spacing: 16) {
                            AuthorBadge(author: .me)
                            Text("把今天，轻轻收藏。").font(.headline)
                            Text("这里会放着日记。\n让背景陪着文字就好。").font(.subheadline).lineSpacing(5).foregroundStyle(.secondary)
                        }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22)).padding(26)
                    }.frame(height: 270).clipShape(RoundedRectangle(cornerRadius: 22)).listRowInsets(EdgeInsets())
                }
                Section {
                    Toggle("显示背景图", isOn: $style.showsImage)
                    PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
                        Label(loading ? "正在整理图片…" : "从相册选择图片", systemImage: "photo.on.rectangle")
                    }.disabled(loading)
                    Button("使用 Miu 的默认插画") { style.imageName = nil; style.showsImage = true }
                    VStack(alignment: .leading) {
                        Text("柔和遮罩 \(Int(style.veil * 100))%").font(.subheadline)
                        Slider(value: $style.veil, in: 0...0.9).accessibilityLabel("背景遮罩")
                    }
                    VStack(alignment: .leading) {
                        Text("背景模糊 \(Int(style.blur))").font(.subheadline)
                        Slider(value: $style.blur, in: 0...12).accessibilityLabel("背景模糊")
                    }
                } header: { Text("背景") } footer: { Text(day == nil ? "用于所有未单独设置背景的日期；与月历背景分别保存。" : "只改变这一天的背景，其他日子会保留自己的模样。") }
                if let day {
                    Section {
                        Button("这一天跟随默认背景") {
                            do { try store.resetDayStyle(day); dismiss() }
                            catch { issue = AlertMessage(text: error.localizedDescription) }
                        }
                    }
                }
            }.navigationTitle(day == nil ? "单日默认背景" : "这一天的模样").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            do { try store.setStyle(style, for: day); dismiss() }
                            catch { issue = AlertMessage(text: error.localizedDescription) }
                        }.disabled(loading)
                    }
                }
        }
        .onAppear { if !loaded { style = store.style(for: day); loaded = true } }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            loading = true
            Task { @MainActor in
                defer { loading = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw DiaryFailure.message("没有读到图片，请再选一次。") }
                    style.imageName = try store.storeImage(data); style.showsImage = true
                } catch { issue = AlertMessage(text: error.localizedDescription) }
            }
        }
        .alert(item: $issue) { item in Alert(title: Text("背景还没换好"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
}

struct TrashView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleting: DiaryEntry?
    @State private var issue: AlertMessage?
    private var entries: [DiaryEntry] { store.library.entries.filter { $0.deletedAt != nil }.sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) } }
    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty { EmptyPage(symbol: "tray", title: "回收站是空的", subtitle: "移走的日记会留在这里，不会自动清理。") }
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { AuthorBadge(author: entry.author, moment: entry.writingMoment); Spacer(); Text(entry.day).font(.caption).foregroundStyle(.secondary) }
                        Text(entry.overviewTitle).font(.headline)
                        HStack {
                            Button("放回原来的日期") {
                                do { try store.setDeleted(entry.id, deleted: false) }
                                catch { issue = AlertMessage(text: error.localizedDescription) }
                            }.buttonStyle(.borderless)
                            Spacer()
                            Button("彻底删除", role: .destructive) { deleting = entry }.buttonStyle(.borderless)
                        }.font(.caption)
                    }.padding(.vertical, 8)
                }
            }.navigationTitle("回收站").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .confirmationDialog("彻底删除这一篇？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("彻底删除", role: .destructive) {
                if let deleting {
                    do { try store.permanentlyDelete(deleting.id) }
                    catch { issue = AlertMessage(text: error.localizedDescription) }
                }
                deleting = nil
            }
        } message: { Text("这会一并删除关联草稿，且无法撤销。之前导出的备份不会改变。") }
        .alert(item: $issue) { item in Alert(title: Text("暂时没有完成"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
}

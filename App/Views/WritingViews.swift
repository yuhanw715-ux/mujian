import SwiftUI
import UniformTypeIdentifiers

struct AddEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let day: String
    @State private var author = DiaryAuthor.me
    @State private var editing: DiaryDraft?
    @State private var importing = false
    @State private var imported: ImportFile?
    @State private var issue: AlertMessage?
    var body: some View {
        Group {
            if let editing { EditorView(initial: editing) }
            else if let imported { ImportReviewView(file: imported, suggestedDay: day, fallbackAuthor: author) }
            else {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 26) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("今天的心事，\n放在这一页。").font(.system(size: 30, weight: .bold, design: .rounded))
                            Text("你写的、Miu 写的，都值得好好收藏。")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.top, 20)
                        Picker("这是谁写的", selection: $author) {
                            ForEach(DiaryAuthor.allCases) { Text($0.label).tag($0) }
                        }.pickerStyle(.segmented)
                        action("在这里写", subtitle: "慢慢写，没写完也会留下草稿。", symbol: "square.and.pencil") {
                            editing = DiaryDraft(day: day, author: author)
                        }
                        action("导入 TXT", subtitle: "一份文件，收藏成一篇日记。", symbol: "doc.badge.plus") { importing = true }
                        Spacer()
                        Text("所有文字和图片只保存在本机。")
                            .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }.padding(24).background(MiuTheme.page)
                        .navigationTitle("添一篇日记").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
                }
            }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .text], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                guard url.pathExtension.lowercased() == "txt" else { throw DiaryFailure.message("请选一个 .txt 文件，Miu 会把它完整收藏成一篇。") }
                imported = ImportFile(name: url.lastPathComponent, data: try LocalFiles.read(url, limit: DiaryRules.maxTextBytes))
            } catch { issue = AlertMessage(text: error.localizedDescription) }
        }
        .alert(item: $issue) { item in Alert(title: Text("暂时没有导入"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
    private func action(_ title: String, subtitle: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.title2).frame(width: 48, height: 48)
                    .background(MiuTheme.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption)
            }.padding(18).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain)
    }
}

struct EditorView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: DiaryDraft
    @State private var committed = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var status = "写到一半也没关系。"
    @State private var issue: AlertMessage?
    @State private var datePicker = false
    @FocusState private var focused: Bool
    init(initial: DiaryDraft) { _draft = State(initialValue: initial) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Picker("作者", selection: $draft.author) {
                        ForEach(DiaryAuthor.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    HStack {
                        Button { datePicker = true } label: { Label(MiuTheme.date(draft.day, template: "yyyy年 M月d日"), systemImage: "calendar") }
                        Spacer()
                        Text(status).font(.caption2).foregroundStyle(.secondary)
                    }.font(.subheadline)
                    TextField("给今天起个小标题（可选）", text: $draft.title)
                        .font(.title2.weight(.semibold)).focused($focused)
                        .onChange(of: draft.title) { _, title in
                            if title.count > 200 { draft.title = String(title.prefix(200)) }
                        }
                    Divider()
                }.padding(.horizontal, 22).padding(.top, 20)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draft.body).font(.system(size: store.library.readerFontSize)).lineSpacing(7)
                        .scrollContentBackground(.hidden).padding(.horizontal, 17).padding(.top, 8).focused($focused)
                        .accessibilityLabel("日记正文")
                    if draft.body.isEmpty {
                        Text("从一个小小的瞬间写起吧……").foregroundStyle(.tertiary)
                            .padding(.horizontal, 22).padding(.top, 16).allowsHitTesting(false)
                    }
                }
            }.background(MiuTheme.page)
                .navigationTitle(draft.entryID == nil ? "写一页今天" : "继续这一页").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("稍后再写") {
                            if flushDraft() { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("收藏") {
                            autosaveTask?.cancel()
                            do { try store.save(draft); committed = true; dismiss() }
                            catch { issue = AlertMessage(text: error.localizedDescription) }
                        }.fontWeight(.semibold).disabled(draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { focused = false } }
                }
        }
        .interactiveDismissDisabled(draft.hasContent)
        .onChange(of: draft) { _, _ in
            guard !committed else { return }
            status = "正在记下…"
            autosaveTask?.cancel()
            autosaveTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
                guard !Task.isCancelled else { return }
                _ = flushDraft()
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { _ = flushDraft() } }
        .onDisappear { autosaveTask?.cancel(); if !committed { _ = flushDraft() } }
        .sheet(isPresented: $datePicker) {
            DiaryDatePicker(initial: draft.day) { draft.day = $0 }
        }
        .alert(item: $issue) { item in Alert(title: Text("还没有保存好"), message: Text(item.text), dismissButton: .default(Text("返回继续"))) }
    }
    @discardableResult private func flushDraft() -> Bool {
        guard !committed else { return true }
        autosaveTask?.cancel()
        var copy = draft
        copy.updatedAt = Date()
        do {
            try store.saveDraft(copy)
            status = draft.hasContent ? "草稿已记下" : "写到一半也没关系。"
            return true
        } catch { status = "草稿未保存"; issue = AlertMessage(text: error.localizedDescription); return false }
    }
}

struct DiaryDatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    let selected: (String) -> Void
    init(initial: String, selected: @escaping (String) -> Void) {
        _date = State(initialValue: DayKey.date(initial) ?? Date()); self.selected = selected
    }
    var body: some View {
        NavigationStack {
            DatePickerDecoration(day: DayKey.make(date)) {
                DatePicker("存放日期", selection: $date,
                           in: DayKey.date("1900-01-01")!...DayKey.date("2199-12-31")!, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }.navigationTitle("放在哪一天？").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("选好啦") { selected(DayKey.make(date)); dismiss() } }
                }
        }.presentationDetents([.large])
    }
}

struct ImportReviewView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    let file: ImportFile
    let suggestedDay: String
    @State private var author: DiaryAuthor
    @State private var day: String?
    @State private var title = ""
    @State private var bodyText = ""
    @State private var encoding = TextEncodingChoice.auto
    @State private var decodingIssue: String?
    @State private var datePicker = false
    @State private var duplicate = false
    @State private var issue: AlertMessage?
    private let ambiguous: Bool
    init(file: ImportFile, suggestedDay: String, fallbackAuthor: DiaryAuthor) {
        self.file = file; self.suggestedDay = suggestedDay
        let dates = DayKey.dates(inFilename: file.name)
        _day = State(initialValue: dates.count == 1 ? dates[0] : nil)
        ambiguous = dates.count > 1
        _author = State(initialValue: file.name.range(of: "miu", options: .caseInsensitive) != nil ? .miu : fallbackAuthor)
        _title = State(initialValue: String((file.name as NSString).deletingPathExtension.prefix(200)))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(file.name, systemImage: "doc.text").font(.subheadline)
                    Picker("谁写的", selection: $author) { ForEach(DiaryAuthor.allCases) { Text($0.label).tag($0) } }
                    Button { datePicker = true } label: {
                        HStack {
                            Text("存放日期").foregroundStyle(.primary)
                            Spacer()
                            Text(day.map { MiuTheme.date($0, template: "yyyy年 M月d日") } ?? "请先选择日期")
                        }
                    }
                    TextField("标题（可选）", text: $title).onChange(of: title) { _, value in if value.count > 200 { title = String(value.prefix(200)) } }
                } header: { Text("先看一眼，再收藏") } footer: {
                    Text(day == nil ? (ambiguous ? "文件名里有多个日期，请确认这篇日记属于哪一天。" : "文件名里没有完整日期，请为这一篇选个日子。") : "请核对日期和作者；一份 TXT 会保存为一篇完整日记。")
                }
                Section("文字预览") {
                    Picker("文件编码", selection: $encoding) { ForEach(TextEncodingChoice.allCases) { Text($0.label).tag($0) } }
                    if let decodingIssue { Text(decodingIssue).foregroundStyle(.orange) }
                    else {
                        Text(verbatim: String(bodyText.prefix(8000))).font(.system(size: 15)).lineSpacing(5).textSelection(.enabled)
                        if bodyText.count > 8000 { Text("预览显示前 8,000 字，保存时会保留全部文字。\n共 \(bodyText.count) 字").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("收藏一份 TXT").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认收藏") {
                        guard let day else { datePicker = true; return }
                        if DiaryRules.isDuplicate(body: bodyText, day: day, author: author, in: store.library) { duplicate = true }
                        else { save() }
                    }.disabled(day == nil || bodyText.isEmpty || decodingIssue != nil)
                }
            }
        }
        .onAppear { decode(); if day == nil { datePicker = true } }
        .onChange(of: encoding) { _, _ in decode() }
        .sheet(isPresented: $datePicker) { DiaryDatePicker(initial: day ?? suggestedDay) { day = $0 } }
        .confirmationDialog("同一天已有相同作者、相同正文的日记", isPresented: $duplicate, titleVisibility: .visible) {
            Button("仍然添加一篇") { save() }
            Button("先不添加", role: .cancel) {}
        } message: { Text("原来那篇会保留，不会被覆盖。") }
        .alert(item: $issue) { item in Alert(title: Text("暂时没有收藏"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
    private func decode() {
        do { bodyText = try DiaryRules.decodeText(file.data, choice: encoding); decodingIssue = nil }
        catch { bodyText = ""; decodingIssue = error.localizedDescription }
    }
    private func save() {
        guard let day else { return }
        do {
            let draft = DiaryDraft(day: day, author: author, title: title, body: bodyText, source: .txt, originalFilename: file.name)
            try store.save(draft); dismiss()
        } catch { issue = AlertMessage(text: error.localizedDescription) }
    }
}

struct DraftsView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: DiaryDraft?
    @State private var deleting: DiaryDraft?
    @State private var issue: AlertMessage?
    var body: some View {
        NavigationStack {
            List {
                if store.drafts.isEmpty { EmptyPage(symbol: "pencil.and.outline", title: "草稿箱空空的", subtitle: "写到一半的日记，会在这里等你。") }
                ForEach(store.drafts) { draft in
                    Button { editing = draft } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { AuthorBadge(author: draft.author); Spacer(); Text(draft.day).font(.caption).foregroundStyle(.secondary) }
                            Text(draft.title.isEmpty ? "还没起名字的一页" : draft.title).foregroundStyle(.primary)
                            Text(String(draft.body.prefix(250))).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }.padding(.vertical, 6)
                    }.swipeActions { Button("删除", role: .destructive) { deleting = draft } }
                }
            }.navigationTitle("草稿箱").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .sheet(item: $editing) { EditorView(initial: $0) }
        .confirmationDialog("删除这份草稿？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除草稿", role: .destructive) {
                if let deleting {
                    do { try store.discardDraft(deleting.id) } catch { issue = AlertMessage(text: error.localizedDescription) }
                }
                deleting = nil
            }
        } message: { Text("草稿删除后无法找回。已经收藏的原日记不受影响。") }
        .alert(item: $issue) { item in Alert(title: Text("暂时没有删除"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
}

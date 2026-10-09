import SwiftUI

enum DiaryRoute: Hashable { case day(String), entry(UUID) }

struct HomeView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var month = DayKey.monthStart(Date())
    @State private var section = 0
    @State private var path: [DiaryRoute] = []
    @State private var settings = false
    @State private var drafts = false
    @State private var monthPicker = false
    @State private var newEntry: NewEntryContext?
    @State private var search = ""
    @Namespace private var navigation
    private var today: String { DayKey.make(Date()) }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if section == 0 { calendar }
                else { DiaryListView(search: $search, namespace: navigation) }
            }
            .background(MiuTheme.page)
            .navigationTitle(section == 0 ? "暮笺" : "日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { monthPicker = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.caption.weight(.semibold))
                            Text(String(DayKey.calendar.component(.year, from: month)) + "年")
                        }
                    }.accessibilityLabel("选择年月")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { section = 1 } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("查找日记")
                    Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("设置")
                    Button { newEntry = NewEntryContext(day: today) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("添加日记").disabled(store.isReadOnly)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .navigationDestination(for: DiaryRoute.self) { route in
                switch route {
                case .day(let day):
                    DayView(day: day, namespace: navigation)
                        .miuZoomDestination(day, in: navigation, enabled: !reduceMotion)
                case .entry(let id):
                    ReaderView(entryID: id)
                        .miuZoomDestination(id, in: navigation, enabled: !reduceMotion)
                }
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $drafts) { DraftsView() }
        .sheet(isPresented: $monthPicker) { MonthPickerView(month: $month) }
        .sheet(item: $newEntry) { context in AddEntryView(day: context.day) }
        .alert("Miu 的小提示", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("知道啦", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var calendar: some View {
        GeometryReader { geometry in
            let cells = DayKey.monthCells(month)
            let rows = cells.count / 7
            let height = max(102.0, min(155.0, (geometry.size.height - 128) / CGFloat(rows)))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(MiuTheme.date(DayKey.make(month), template: "M月")).font(.system(size: 36, weight: .bold, design: .rounded))
                        Spacer()
                        Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 44) }.accessibilityLabel("上个月")
                        Button { changeMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 44) }.accessibilityLabel("下个月")
                    }.padding(.horizontal, 22).padding(.top, 12)
                    HStack(spacing: 12) {
                        legend("我写的", color: MiuTheme.lavender)
                        legend("Miu写的", color: MiuTheme.rose)
                        Spacer()
                        if !store.drafts.isEmpty {
                            Button("草稿 \(store.drafts.count)") { drafts = true }.font(.caption)
                        }
                    }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 18)
                    if let issue = store.loadIssue {
                        Label(issue, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).padding()
                    }
                    HStack(spacing: 0) {
                        ForEach(Array(["日", "一", "二", "三", "四", "五", "六"].enumerated()), id: \.offset) { index, label in
                            Text(label).font(.caption.weight(.medium)).foregroundStyle(index == 0 || index == 6 ? .secondary : .primary).frame(maxWidth: .infinity)
                        }
                    }.padding(.bottom, 10)
                    VStack(spacing: 0) {
                        ForEach(0..<rows, id: \.self) { row in
                            Divider().opacity(0.5)
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(0..<7, id: \.self) { col in
                                    if let day = cells[row * 7 + col] {
                                        NavigationLink(value: DiaryRoute.day(day)) {
                                            CalendarDayCell(day: day, entries: store.library.entries(on: day), isToday: day == today, weekend: col == 0 || col == 6)
                                                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
                                        }.buttonStyle(.plain).miuZoomSource(day, in: navigation)
                                    } else { Color.clear.frame(maxWidth: .infinity).frame(height: height) }
                                }
                            }
                        }
                    }.padding(.horizontal, 8)
                    if store.library.activeEntries.isEmpty {
                        Text("把平常的一天，也轻轻收藏起来。")
                            .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
                if abs(value.translation.width) > 75 && abs(value.translation.width) > abs(value.translation.height) * 1.8 {
                    changeMonth(value.translation.width < 0 ? 1 : -1)
                }
            })
        }
    }

    private var bottomBar: some View {
        HStack {
            Button("今天") {
                withAnimation(MiuTheme.motion(reduceMotion)) { month = DayKey.monthStart(Date()); section = 0 }
            }.font(.subheadline.weight(.semibold)).padding(.horizontal, 20).frame(height: 48)
                .background(.regularMaterial, in: Capsule())
            Spacer()
            HStack(spacing: 4) {
                sectionButton("月历", symbol: "calendar", value: 0)
                sectionButton("日记", symbol: "book.closed", value: 1)
            }.padding(5).background(.regularMaterial, in: Capsule())
        }.padding(.horizontal, 22).padding(.vertical, 10).background(MiuTheme.page.opacity(0.86))
    }
    private func sectionButton(_ label: String, symbol: String, value: Int) -> some View {
        Button { withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.18)) { section = value } } label: {
            Label(label, systemImage: symbol).font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).frame(height: 38)
                .background(section == value ? MiuTheme.lavender.opacity(0.14) : .clear, in: Capsule())
        }
    }
    private func legend(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) { Circle().fill(color).frame(width: 6, height: 6); Text(label).font(.caption2).foregroundStyle(.secondary) }
    }
    private func changeMonth(_ delta: Int) {
        guard let next = DayKey.calendar.date(byAdding: .month, value: delta, to: month),
              (1900...2199).contains(DayKey.calendar.component(.year, from: next)) else { return }
        withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.22)) { month = next }
    }
}

private struct CalendarDayCell: View {
    let day: String
    let entries: [DiaryEntry]
    let isToday: Bool
    let weekend: Bool
    private var number: String { String(Int(day.suffix(2)) ?? 1) }
    var body: some View {
        VStack(spacing: 5) {
            Text(number).font(.system(size: 20, weight: isToday ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isToday ? .white : weekend ? Color.secondary : Color.primary)
                .frame(width: 32, height: 32)
                .background(isToday ? MiuTheme.lavender : .clear, in: Circle()).padding(.top, 5)
            ForEach(Array(entries.prefix(2))) { entry in
                Text(entry.author.label).font(.system(size: 9, weight: .medium))
                    .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 3).padding(.vertical, 4)
                    .foregroundStyle(MiuTheme.color(entry.author))
                    .background(MiuTheme.color(entry.author).opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
            }
            if entries.count > 2 { Text("+\(entries.count - 2)").font(.system(size: 10)).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }.padding(.horizontal, 2).contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(MiuTheme.date(day))，\(entries.count) 篇日记\(isToday ? "，今天" : "")")
    }
}

struct MonthPickerView: View {
    @Binding var month: Date
    @Environment(\.dismiss) private var dismiss
    @State private var chosen = Date()
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker("前往这一天所在的月份", selection: $chosen,
                           in: DayKey.date("1900-01-01")!...DayKey.date("2199-12-31")!, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                Text("选好日期后，Miu 带你回到那个月。")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }.navigationTitle("翻到哪一页？").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("前往") { month = DayKey.monthStart(chosen); dismiss() } }
                }
        }.onAppear { chosen = month }.presentationDetents([.large])
    }
}

struct DiaryListView: View {
    @EnvironmentObject private var store: DiaryStore
    @Binding var search: String
    let namespace: Namespace.ID
    @State private var author = "all"
    @State private var drafts = false
    private var entries: [DiaryEntry] {
        store.library.activeEntries.filter { entry in
            (author == "all" || entry.author.rawValue == author) &&
            (search.isEmpty || entry.title.localizedCaseInsensitiveContains(search) || entry.body.localizedCaseInsensitiveContains(search) || entry.day.contains(search))
        }.sorted { $0.day == $1.day ? $0.createdAt > $1.createdAt : $0.day > $1.day }
    }
    var body: some View {
        List {
            Picker("作者", selection: $author) {
                Text("全部").tag("all")
                Text("我写的").tag("me")
                Text("Miu写的").tag("miu")
            }.pickerStyle(.segmented).listRowBackground(Color.clear)
            if !store.drafts.isEmpty { Button("草稿箱 · \(store.drafts.count) 篇") { drafts = true } }
            if entries.isEmpty {
                EmptyPage(symbol: "book.closed", title: search.isEmpty ? "还没有日记" : "没有找到这一页", subtitle: search.isEmpty ? "写一点今天的心情，或导入一份 TXT。" : "换个词，再找找看。")
                    .listRowBackground(Color.clear)
            }
            ForEach(entries) { entry in
                NavigationLink(value: DiaryRoute.entry(entry.id)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { AuthorBadge(author: entry.author); Spacer(); Text(MiuTheme.date(entry.day, template: "yyyy.MM.dd")).font(.caption).foregroundStyle(.secondary) }
                        Text(entry.displayTitle).font(.headline).lineLimit(2)
                        Text(entry.excerpt).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }.padding(.vertical, 6)
                }.miuZoomSource(entry.id, in: namespace)
            }
        }.listStyle(.insetGrouped).searchable(text: $search, prompt: "找一段文字，或一个日期")
            .sheet(isPresented: $drafts) { DraftsView() }
    }
}

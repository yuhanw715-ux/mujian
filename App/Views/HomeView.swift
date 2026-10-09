import SwiftUI

enum DiaryRoute: Hashable { case day(String), entry(UUID) }

struct HomeView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.miuAccent) private var accent
    @State private var month = DayKey.monthStart(Date())
    @State private var section = 0
    @State private var path: [DiaryRoute] = []
    @State private var settings = false
    @State private var drafts = false
    @State private var monthPicker = false
    @State private var newEntry: NewEntryContext?
    @State private var search = ""
    @Namespace private var navigation
    @Namespace private var tabs
    private var today: String { DayKey.make(Date()) }
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                CalendarBackdrop(animatePaws: path.isEmpty && section == 0).ignoresSafeArea()
                if section == 0 {
                    VStack(spacing: 0) {
                        if let issue = store.loadIssue {
                            Text(issue).font(.caption).foregroundStyle(.orange).padding(12)
                        }
                        HStack(spacing: 12) {
                            legend("我写的", color: MiuTheme.lavender)
                            legend("Miu写的", color: MiuTheme.rose)
                            Spacer()
                            if !store.drafts.isEmpty { Button("草稿 \(store.drafts.count)") { drafts = true }.font(.caption) }
                        }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 5)
                        VerticalCalendar(month: $month, namespace: navigation) { day in
                            path.append(.day(day))
                        }
                    }
                } else { DiaryListView(search: $search, namespace: navigation) }
            }
            .navigationTitle(section == 0 ? "暮笺" : "日记").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { monthPicker = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
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
                    ReaderView(entryID: id).miuZoomDestination(id, in: navigation, enabled: !reduceMotion)
                }
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $drafts) { DraftsView() }
        .sheet(isPresented: $monthPicker) { MonthPickerView(month: $month) }
        .sheet(item: $newEntry) { AddEntryView(day: $0.day) }
        .alert("Miu 的小提示", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("知道啦", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
    private var bottomBar: some View {
        HStack(spacing: 3) {
            tab("今天", symbol: "sun.max", selected: false) {
                withAnimation(MiuTheme.motion(reduceMotion)) { month = DayKey.monthStart(Date()); section = 0 }
            }
            tab("月历", symbol: "calendar", selected: section == 0) { section = 0 }
            tab("日记", symbol: "book.closed", selected: section == 1) { section = 1 }
        }.padding(6).modifier(GlassSurface(radius: 38))
            .shadow(color: accent.opacity(0.13), radius: 18, y: 5)
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 8)
    }
    private func tab(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(MiuTheme.motion(reduceMotion), action) } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 21, weight: .medium))
                Text(title).font(.caption.weight(selected ? .semibold : .regular))
            }.foregroundStyle(selected ? Color.primary : Color.secondary).frame(maxWidth: .infinity).frame(height: 56)
                .background {
                    if selected {
                        Capsule().fill(accent.opacity(0.18))
                            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.7), accent.opacity(0.3), MiuTheme.rose.opacity(0.4), .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                            .matchedGeometryEffect(id: "selected-tab", in: tabs, isSource: true)
                    }
                }.contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) { Circle().fill(color).frame(width: 6, height: 6); Text(title).font(.caption2).foregroundStyle(.secondary) }
    }
}

private struct MonthSnapBehavior: ScrollTargetBehavior {
    let stride: CGFloat
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.y = CGFloat(MonthLayout.snappedOffset(Double(target.rect.minY), stride: Double(stride), maximum: Double(context.contentSize.height - context.containerSize.height)))
        target.anchor = .top
    }
}

struct VerticalCalendar: View {
    @Binding var month: Date
    let namespace: Namespace.ID
    let openDay: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: Int?
    init(month: Binding<Date>, namespace: Namespace.ID, openDay: @escaping (String) -> Void) {
        _month = month; self.namespace = namespace; self.openDay = openDay
        _position = State(initialValue: MonthLayout.index(of: month.wrappedValue))
    }
    var body: some View {
        GeometryReader { geometry in
            let peek: CGFloat = geometry.size.height > 500 ? min(108, geometry.size.height * 0.16) : geometry.size.height > 350 ? 22 : 8
            let pageHeight = max(160, geometry.size.height - peek * 2)
            let stride = pageHeight + 12
            ScrollView(.vertical) {
                LazyVStack(spacing: 12) {
                    ForEach(0..<MonthLayout.count, id: \.self) { index in
                        MonthPage(index: index, height: pageHeight, viewportHeight: geometry.size.height, namespace: namespace, openDay: openDay)
                            .frame(height: pageHeight).id(index)
                            .visualEffect { content, proxy in
                                content.opacity(MonthLayout.opacity(distance: Double(proxy.frame(in: .named("monthViewport")).midY - geometry.size.height / 2), stride: Double(stride)))
                            }
                    }
                }.scrollTargetLayout().padding(.vertical, peek)
            }.coordinateSpace(name: "monthViewport")
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(MonthSnapBehavior(stride: stride))
                .scrollPosition(id: $position, anchor: .center)
                .onChange(of: position) { _, value in
                    if let value, MonthLayout.index(of: month) != value { month = MonthLayout.date(at: value) }
                }
                .onChange(of: month) { _, value in
                    let index = MonthLayout.index(of: value)
                    if position != index { withAnimation(MiuTheme.motion(reduceMotion)) { position = index } }
                }
                .onChange(of: geometry.size) { _, _ in
                    // Re-center after orientation changes, keeping the complete selected month visible.
                    let index = MonthLayout.index(of: month)
                    position = nil
                    Task { @MainActor in await Task.yield(); position = index }
                }
                .accessibilityAction(named: Text("上个月")) { month = MonthLayout.date(at: MonthLayout.index(of: month) - 1) }
                .accessibilityAction(named: Text("下个月")) { month = MonthLayout.date(at: MonthLayout.index(of: month) + 1) }
        }
    }
}

private struct DayFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, next in next }) }
}

private struct MonthPage: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    let height: CGFloat
    let viewportHeight: CGFloat
    let namespace: Namespace.ID
    let openDay: (String) -> Void
    @State private var dayFrames: [String: CGRect] = [:]
    @GestureState(resetTransaction: Transaction(animation: MiuTheme.motion(false))) private var magnification: CGFloat = 1
    private var month: Date { MonthLayout.date(at: index) }
    private var coordinateName: String { "month-\(index)" }
    var body: some View {
        GeometryReader { page in
            let cells = DayKey.monthCells(month)
            let rows = cells.count / 7
            let compact = height < 400
            let headerHeight: CGFloat = compact ? 38 : 48
            let rowHeight = max(18, (height - headerHeight - 24) / CGFloat(rows))
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text(MiuTheme.date(DayKey.make(month), template: "M月")).font(.system(size: compact ? 24 : 35, weight: .bold, design: .rounded))
                    Spacer()
                    if !compact {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("上下翻阅").font(.caption2)
                            Text("双指张开，走进某一天").font(.system(size: 9))
                        }.foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 24).frame(height: headerHeight)
                HStack(spacing: 0) {
                    ForEach(Array(["日", "一", "二", "三", "四", "五", "六"].enumerated()), id: \.offset) { _, title in
                        Text(title).font(.system(size: compact ? 9 : 12, weight: .medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }.frame(height: 24).padding(.horizontal, 12)
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(0..<7, id: \.self) { col in
                                if let day = cells[row * 7 + col] {
                                    Button { openDay(day) } label: {
                                        CalendarDayCell(day: day, entries: store.library.entries(on: day), rowHeight: rowHeight, weekend: col == 0 || col == 6)
                                            .frame(maxWidth: .infinity).frame(height: rowHeight, alignment: .top)
                                    }.buttonStyle(.plain).miuZoomSource(day, in: namespace)
                                        .background(GeometryReader { cell in
                                            Color.clear.preference(key: DayFramePreference.self, value: [day: cell.frame(in: .named(coordinateName))])
                                        })
                                } else { Color.clear.frame(maxWidth: .infinity).frame(height: rowHeight) }
                            }
                        }.overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.075)).frame(height: 0.5).allowsHitTesting(false) }
                            .visualEffect { content, proxy in
                                content.opacity(max(0.70, 1 - abs(proxy.frame(in: .named("monthViewport")).midY - viewportHeight / 2) / max(1, viewportHeight) * 0.55))
                            }
                    }
                }.padding(.horizontal, 12)
            }.frame(width: page.size.width, height: height, alignment: .top)
                .coordinateSpace(name: coordinateName)
                .onPreferenceChange(DayFramePreference.self) { if dayFrames != $0 { dayFrames = $0 } }
                .scaleEffect(reduceMotion ? 1 : min(1.08, max(0.98, magnification)))
                .simultaneousGesture(MagnifyGesture().updating($magnification) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        guard value.magnification >= 1.18 else { return }
                        let point = CGPoint(x: value.startAnchor.x * page.size.width, y: value.startAnchor.y * height)
                        let closest = dayFrames.min { a, b in
                            hypot(a.value.midX - point.x, a.value.midY - point.y) < hypot(b.value.midX - point.x, b.value.midY - point.y)
                        }
                        if let closest { openDay(closest.key) }
                    })
        }
    }
}

private struct CalendarDayCell: View {
    @Environment(\.miuAccent) private var accent
    @Environment(\.accessibilityReduceTransparency) private var solid
    let day: String
    let entries: [DiaryEntry]
    let rowHeight: CGFloat
    let weekend: Bool
    private var isToday: Bool { day == DayKey.make(Date()) }
    private var markers: [DiaryEntry] {
        // Show both authors when both exist, even if one wrote several entries.
        let authors = DiaryAuthor.allCases.compactMap { author in entries.first { $0.author == author } }
        return authors + Array(entries.filter { entry in !authors.contains { $0.id == entry.id } }.prefix(max(0, 2 - authors.count)))
    }
    var body: some View {
        let compact = rowHeight < 100
        let diameter = min(34, max(20, rowHeight - 4))
        VStack(spacing: compact ? 2 : 4) {
            Text(String(Int(day.suffix(2)) ?? 1)).font(.system(size: compact ? 16 : 21, weight: isToday ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isToday ? Color.primary : weekend ? Color.secondary : Color.primary)
                .frame(width: diameter, height: diameter)
                .background {
                    if isToday {
                        Circle().fill(solid ? AnyShapeStyle(accent.opacity(0.25)) : AnyShapeStyle(.ultraThinMaterial))
                            .overlay(Circle().fill(accent.opacity(0.12)))
                            .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.75), accent.opacity(0.45), .white.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                    }
                }.padding(.top, compact ? 1 : 7)
            if compact {
                if rowHeight >= 50 {
                    HStack(spacing: 2) {
                        ForEach(markers) { entry in
                            Text(entry.author.shortLabel).font(.system(size: 8, weight: .medium))
                                .padding(.horizontal, 3).padding(.vertical, 2)
                                .foregroundStyle(MiuTheme.color(entry.author))
                                .background(MiuTheme.color(entry.author).opacity(0.15), in: Capsule())
                        }
                        if entries.count > 2 { Text("+\(entries.count - 2)").font(.system(size: 7)).foregroundStyle(.secondary) }
                    }.lineLimit(1).minimumScaleFactor(0.7)
                } else if rowHeight >= 34 {
                    HStack(spacing: 3) { ForEach(markers) { Circle().fill(MiuTheme.color($0.author)).frame(width: 3, height: 3) } }
                }
            } else {
                ForEach(markers) { entry in
                    Text(entry.author.label).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 3).padding(.vertical, 3)
                        .foregroundStyle(MiuTheme.color(entry.author))
                        .background(MiuTheme.color(entry.author).opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                }
                if entries.count > 2 { Text("+\(entries.count - 2)").font(.system(size: 9)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 2).contentShape(Rectangle()).accessibilityElement(children: .ignore)
            .accessibilityLabel("\(MiuTheme.date(day))，\(entries.count) 篇日记\(isToday ? "，今天" : "")")
    }
}

struct MonthPickerView: View {
    @Binding var month: Date
    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Date
    init(month: Binding<Date>) { _month = month; _chosen = State(initialValue: month.wrappedValue) }
    var body: some View {
        NavigationStack {
            DatePickerDecoration(day: DayKey.make(chosen)) {
                DatePicker("前往这一天所在的月份", selection: $chosen,
                           in: DayKey.date("1900-01-01")!...DayKey.date("2199-12-31")!, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }.navigationTitle("翻到哪一页？").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("前往") { month = DayKey.monthStart(chosen); dismiss() } }
                }
        }.presentationDetents([.large])
    }
}

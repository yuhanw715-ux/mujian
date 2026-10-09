import SwiftUI

struct DiaryListView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.miuAccent) private var accent
    @Binding var search: String
    @State private var author = DiaryBrowseAuthor.all
    @State private var differencesOnly = false
    @State private var drafts = false
    @FocusState private var searching: Bool
    private var allGroups: [DiaryDayGroup] { DiaryDayGroup.grouped(store.library.entries) }
    private var groups: [DiaryDayGroup] {
        allGroups.filter { $0.matches(author: author, query: search, differencesOnly: differencesOnly) }
    }
    private var mineCount: Int { store.library.activeEntries.filter { $0.author == .me }.count }
    private var miuCount: Int { store.library.activeEntries.filter { $0.author == .miu }.count }
    var body: some View {
        // No List background here: the same CalendarBackdrop remains visible in both tabs.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("一起收好的日子").font(.title2.weight(.semibold))
                    Text("两份日常，慢慢放在同一页。").font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 0) {
                        countItem("小暮暮", count: mineCount, color: MiuTheme.lavender)
                        Divider().frame(height: 38)
                        countItem("Miu", count: miuCount, color: MiuTheme.rose)
                        Divider().frame(height: 38)
                        countItem("相差篇数", count: abs(mineCount - miuCount), color: .secondary)
                    }.padding(.top, 8)
                }.padding(20).modifier(DiaryPaperSurface())
                searchField
                VStack(alignment: .leading, spacing: 12) {
                    Picker("查看谁的日记", selection: $author) {
                        ForEach(DiaryBrowseAuthor.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    HStack(spacing: 10) {
                        Button { differencesOnly.toggle() } label: {
                            Label("篇数不同 · \(allGroups.filter(\.hasDifferentCounts).count) 天",
                                  systemImage: differencesOnly ? "checkmark.circle.fill" : "circle")
                                .font(.caption.weight(.medium)).foregroundStyle(.primary)
                                .padding(.horizontal, 12).frame(minHeight: 44)
                                .background(accent.opacity(differencesOnly ? 0.20 : 0.07), in: Capsule())
                        }.buttonStyle(.plain).accessibilityAddTraits(differencesOnly ? .isSelected : [])
                        Spacer(minLength: 0)
                        if !store.drafts.isEmpty {
                            Button { drafts = true } label: {
                                Label("草稿 \(store.drafts.count)", systemImage: "square.and.pencil").font(.caption).frame(minHeight: 44)
                            }
                        }
                    }
                    Text("搜索小暮暮的文字、作者或日期。Miu 的正文只在单日里点开后显示。")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(16).modifier(DiaryPaperSurface())
                if groups.isEmpty {
                    EmptyPage(symbol: differencesOnly ? "books.vertical" : "book.closed",
                              title: differencesOnly ? "这里暂时没有篇数不同的日期" : search.isEmpty ? "还没有收藏的日子" : "没有找到这一页",
                              subtitle: differencesOnly ? "可以关闭筛选，看看全部日记。" : search.isEmpty ? "写一点今天的心情，或导入一份 TXT。" : "试试日期，或小暮暮日记里的词。")
                        .modifier(DiaryPaperSurface())
                } else {
                    Text("\(groups.count) 个日期 · 最近的在前面").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                    ForEach(groups) { group in
                        // Both authors open the day first. Miu's full text is reachable only
                        // by deliberately tapping its card from that single-day page.
                        NavigationLink(value: DiaryRoute.day(group.day)) {
                            DiaryDayCollectionCard(group: group, author: author, query: search)
                        }.buttonStyle(DiaryCollectionPressStyle())
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 22)
                .frame(maxWidth: 860).frame(maxWidth: .infinity)
        }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $drafts) { DraftsView() }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { searching = false } }
            }
    }
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("找文字、作者，或一个日期", text: $search).focused($searching)
                .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                .onSubmit { searching = false }
                .accessibilityLabel("搜索小暮暮的日记文字、作者或日期")
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("清除搜索")
            }
        }.padding(.leading, 16).padding(.trailing, search.isEmpty ? 16 : 4).frame(minHeight: 52)
            .modifier(GlassSurface(radius: 19))
    }
    private func countItem(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 7) {
            Text("\(count)").font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(.primary)
            HStack(spacing: 4) { Circle().fill(color).frame(width: 5, height: 5); Text(title).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel("\(title)，\(count) 篇")
    }
}

private struct DiaryDayCollectionCard: View {
    let group: DiaryDayGroup
    let author: DiaryBrowseAuthor
    let query: String
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 2) {
                    Text(String(Int(group.day.suffix(2)) ?? 1)).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(MiuTheme.date(group.day, template: "EEEE")).font(.caption2).foregroundStyle(.secondary)
                }.frame(minWidth: 46)
                VStack(alignment: .leading, spacing: 6) {
                    Text(MiuTheme.date(group.day, template: "yyyy年 M月")).font(.subheadline.weight(.semibold))
                    Text("小暮暮 \(group.mine.count) · Miu \(group.miu.count)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }.foregroundStyle(.primary)
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
            if author == .all && !typeSize.isAccessibilitySize {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        authorPanel(.miu).frame(minWidth: 190)
                        authorPanel(.me).frame(minWidth: 190)
                    }
                    VStack(alignment: .leading, spacing: 16) { authorPanel(.miu); authorPanel(.me) }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if author != .me { authorPanel(.miu) }
                    if author != .miu { authorPanel(.me) }
                }
            }
            HStack {
                Text("走进这一天").font(.caption.weight(.medium))
                Spacer()
                if group.hasDifferentCounts { Text("相差 \(abs(group.mine.count - group.miu.count)) 篇").font(.caption2) }
            }.foregroundStyle(.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).modifier(DiaryPaperSurface())
            .contentShape(RoundedRectangle(cornerRadius: 24))
    }
    @ViewBuilder private func authorPanel(_ requested: DiaryAuthor) -> some View {
        let entries = requested == .me ? group.mine : group.miu
        if let entry = entries.last(where: { $0.matchesOverviewSearch(query) }) ?? entries.last {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    AuthorBadge(author: requested, moment: entry.writingMoment)
                    Spacer(minLength: 0)
                    if entries.count > 1 { Text("\(entries.count) 篇").font(.caption2).foregroundStyle(.secondary) }
                }
                if requested == .miu {
                    SealedDiaryPreview(message: "Miu 的这一页已收好，到单日里再翻开。")
                } else {
                    Text(entry.overviewTitle).font(.headline).foregroundStyle(.primary).lineLimit(1)
                    Text(entry.overviewExcerpt).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    // Show every writing kind present that day, even with more than two entries.
                    HStack(spacing: 6) {
                        ForEach(WritingMoment.allCases.filter { moment in entries.contains { $0.writingMoment == moment } }) { WritingMomentBadge(moment: $0) }
                        if entries.contains(where: { $0.writingMoment == nil }) { WritingMomentBadge(moment: nil) }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label("\(requested.shortLabel) · 这一天还没收藏", systemImage: "book.closed")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DiaryPaperSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var solid
    func body(content: Content) -> some View {
        content.background(solid ? AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)) : AnyShapeStyle(.regularMaterial), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7))
    }
}

private struct DiaryCollectionPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

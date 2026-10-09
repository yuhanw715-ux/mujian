import SwiftUI

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

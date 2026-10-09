import SwiftUI
import UniformTypeIdentifiers

struct DayBackground: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.colorScheme) private var scheme
    var day: String?
    var preview: BackgroundStyle? = nil
    var body: some View {
        let style = preview ?? store.style(for: day)
        GeometryReader { geometry in
            ZStack {
                MiuTheme.page
                if style.showsImage {
                    Group {
                        if let name = style.imageName, let image = store.image(named: name) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else { Image("DayWallpaper").resizable().scaledToFill() }
                    }.frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped().blur(radius: style.blur)
                    (scheme == .dark ? Color.black : Color.white).opacity(style.veil)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct DayView: View {
    @EnvironmentObject private var store: DiaryStore
    let day: String
    let namespace: Namespace.ID
    @State private var newEntry: NewEntryContext?
    @State private var appearance = false
    private var entries: [DiaryEntry] { store.library.entries(on: day) }
    var body: some View {
        ZStack {
            DayBackground(day: day)
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(MiuTheme.date(day, template: "yyyy年 M月d日"))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                            Text("\(MiuTheme.date(day, template: "EEEE")) · \(entries.count) 篇小小的回忆")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.top, 18)
                        if entries.isEmpty {
                            EmptyPage(symbol: "moon.stars", title: "这一天，留一点什么呢？", subtitle: "你写一篇，Miu 的那一篇也可以放在这里。")
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: geometry.size.width > 650 ? 300 : max(240, geometry.size.width - 48)), spacing: 18)], alignment: .leading, spacing: 18) {
                            ForEach(entries) { entry in
                                NavigationLink(value: DiaryRoute.entry(entry.id)) { DiaryCard(entry: entry) }
                                    .buttonStyle(DiaryPressStyle()).miuZoomSource(entry.id, in: namespace)
                            }
                        }
                        Text(entries.isEmpty ? "不必写得很特别，今天的你就很好。" : "这一页的你，Miu 好好收着。")
                            .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 8)
                    }.padding(.horizontal, 22).padding(.bottom, 100).frame(maxWidth: 1000).frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("这一天").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { appearance = true } label: { Image(systemName: "photo") }.accessibilityLabel("这一天的背景")
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button { newEntry = NewEntryContext(day: day) } label: {
                    Label("添一篇", systemImage: "plus").font(.headline).padding(.horizontal, 22).frame(height: 54)
                        .foregroundStyle(.white).background(MiuTheme.lavender, in: Capsule())
                        .shadow(color: MiuTheme.lavender.opacity(0.25), radius: 12, y: 6)
                }.disabled(store.isReadOnly)
            }.padding(.horizontal, 24).padding(.bottom, 8)
        }
        .sheet(item: $newEntry) { context in AddEntryView(day: context.day) }
        .sheet(isPresented: $appearance) { AppearanceView(day: day) }
    }
}

private struct DiaryPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct DiaryCard: View {
    let entry: DiaryEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                AuthorBadge(author: entry.author)
                Spacer()
                Text(entry.source == .txt ? "TXT 收藏" : "写在暮笺").font(.caption2).foregroundStyle(.secondary)
            }
            Text(entry.displayTitle).font(.title3.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
            Text(entry.excerpt).font(.subheadline).lineSpacing(6).foregroundStyle(.secondary)
                .lineLimit(4).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text("轻轻翻开").font(.caption)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption.weight(.medium))
            }.foregroundStyle(MiuTheme.color(entry.author))
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.3), lineWidth: 1))
    }
}

struct ReaderView: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @State private var editing: DiaryDraft?
    @State private var confirmDelete = false
    @State private var exportDocument: DiaryFileDocument?
    @State private var exporting = false
    @State private var exportName = "日记.txt"
    @State private var issue: AlertMessage?
    var body: some View {
        Group {
            if let entry = store.entry(entryID) {
                ZStack {
                    DayBackground(day: entry.day)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            HStack { AuthorBadge(author: entry.author); Spacer(); Text(MiuTheme.date(entry.day, template: "yyyy.MM.dd")).font(.caption).foregroundStyle(.secondary) }
                            Text(entry.displayTitle).font(.system(size: 29, weight: .bold, design: .rounded)).textSelection(.enabled)
                            Divider()
                            Text(verbatim: entry.body).font(.system(size: store.library.readerFontSize))
                                .lineSpacing(9).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            if let filename = entry.originalFilename {
                                Text("来自 \(filename)").font(.caption2).foregroundStyle(.secondary).padding(.top, 16)
                            }
                        }.padding(26).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
                            .frame(maxWidth: 820).padding(.horizontal, 18).padding(.vertical, 20).frame(maxWidth: .infinity)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { editing = store.draft(for: entry) } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("编辑日记")
                        Menu {
                            Button("导出 TXT", systemImage: "square.and.arrow.up") {
                                exportName = "\(entry.day)_\(entry.author.shortLabel).txt"
                                exportDocument = DiaryFileDocument(data: Data(entry.body.utf8)); exporting = true
                            }
                            Button("移到回收站", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        } label: { Image(systemName: "ellipsis.circle") }.accessibilityLabel("日记操作")
                    }
                }
            } else { EmptyPage(symbol: "book.closed", title: "这一页已收起", subtitle: "可以返回月历，继续看看其他日记。") }
        }
        .navigationTitle("读一页时光").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { draft in EditorView(initial: draft) }
        .confirmationDialog("把这一篇移到回收站？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("移到回收站", role: .destructive) {
                do { try store.setDeleted(entryID, deleted: true); dismiss() }
                catch { issue = AlertMessage(text: error.localizedDescription) }
            }
        } message: { Text("之后可以在设置的回收站中找回来。") }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .plainText, defaultFilename: exportName) { result in
            if case .failure(let error) = result { issue = AlertMessage(text: error.localizedDescription) }
        }
        .alert(item: $issue) { item in Alert(title: Text("Miu 的小提示"), message: Text(item.text), dismissButton: .default(Text("知道啦"))) }
    }
}

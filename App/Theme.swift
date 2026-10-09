import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension AccentPalette {
    var color: Color {
        switch self {
        case .lavender: return MiuTheme.lavender
        case .rose: return Color(red: 0.77, green: 0.47, blue: 0.62)
        case .sky: return Color(red: 0.39, green: 0.60, blue: 0.79)
        case .mint: return Color(red: 0.34, green: 0.65, blue: 0.58)
        }
    }
}
extension ThemeMode {
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}
private struct MiuAccentKey: EnvironmentKey { static let defaultValue = MiuTheme.lavender }
extension EnvironmentValues {
    var miuAccent: Color { get { self[MiuAccentKey.self] } set { self[MiuAccentKey.self] = newValue } }
}

struct GlassSurface: ViewModifier {
    @Environment(\.miuAccent) private var accent
    @Environment(\.accessibilityReduceTransparency) private var solid
    var radius: CGFloat = 26
    func body(content: Content) -> some View {
        content
            .background(solid ? AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)) : AnyShapeStyle(.ultraThinMaterial), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(
                LinearGradient(colors: [.white.opacity(0.38), accent.opacity(0.16), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
    }
}

enum MiuTheme {
    static let lavender = Color(red: 0.52, green: 0.43, blue: 0.70)
    static let rose = Color(red: 0.76, green: 0.43, blue: 0.54)
    static let later = Color(uiColor: .systemTeal)
    static let page = Color(uiColor: .systemGroupedBackground)
    static func color(_ author: DiaryAuthor) -> Color { author == .me ? lavender : rose }
    static func color(_ author: DiaryAuthor, moment: WritingMoment?) -> Color {
        guard author == .me else { return rose }
        switch moment { case .onDay: return lavender; case .later: return later; case nil: return .secondary }
    }
    static func color(_ entry: DiaryEntry) -> Color { color(entry.author, moment: entry.writingMoment) }
    static func motion(_ reduce: Bool) -> Animation { reduce ? .linear(duration: 0.12) : .spring(response: 0.52, dampingFraction: 0.91) }
    static func date(_ key: String, template: String = "M月d日 EEEE") -> String {
        guard let date = DayKey.date(key) else { return key }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = template
        return formatter.string(from: date)
    }
}

struct AuthorBadge: View {
    let author: DiaryAuthor
    var moment: WritingMoment? = nil
    var body: some View {
        Label(author.label, systemImage: author == .me ? "pencil.line" : "sparkles")
            .font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(.primary)
            .background(MiuTheme.color(author, moment: moment).opacity(0.15), in: Capsule())
    }
}

struct WritingMomentBadge: View {
    let moment: WritingMoment?
    var body: some View {
        Label(moment?.label ?? "未标记", systemImage: moment?.symbol ?? "circle.dashed")
            .font(.caption2.weight(.medium)).foregroundStyle(.primary)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(MiuTheme.color(.me, moment: moment).opacity(0.14), in: Capsule())
    }
}

struct WritingMomentPicker: View {
    @Binding var selection: WritingMoment?
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("小暮暮，这篇是哪时写下的？").font(.caption).foregroundStyle(.secondary)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(WritingMoment.allCases) { moment in
                    Button { selection = moment } label: {
                        HStack(spacing: 6) {
                            Image(systemName: moment.symbol).foregroundStyle(MiuTheme.color(.me, moment: moment))
                            Text(moment.label).foregroundStyle(.primary)
                            if selection == moment { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.primary) }
                        }.font(.subheadline).frame(maxWidth: .infinity).frame(minHeight: 44)
                            .background(MiuTheme.color(.me, moment: moment).opacity(selection == moment ? 0.18 : 0.06), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(MiuTheme.color(.me, moment: moment).opacity(selection == moment ? 0.6 : 0.16), lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityAddTraits(selection == moment ? .isSelected : [])
                }
            }
            if selection == nil { Text("选一种颜色再收藏；依据写下的时间，不是导入时间。").font(.caption2).foregroundStyle(.secondary) }
        }
    }
}

struct SealedDiaryPreview: View {
    var message = "正文轻轻收好，等你翻开。"
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope").font(.title3).foregroundStyle(MiuTheme.rose)
                .frame(width: 42, height: 42).background(MiuTheme.rose.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            Text(message).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}

struct EmptyPage: View {
    let symbol: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light)).foregroundStyle(MiuTheme.lavender)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(32).frame(maxWidth: .infinity)
    }
}

struct DiaryFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText, .data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum LocalFiles {
    static func read(_ url: URL, limit: Int) throws -> Data {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { readableURL in
            readResult = Result { try BoundedFileReader.read(readableURL, limit: limit) }
        }
        if let coordinationError { throw coordinationError }
        guard let readResult else { throw DiaryFailure.message("文件还没有准备好，请在‘文件’中下载后再试一次。") }
        return try readResult.get()
    }
}

struct AlertMessage: Identifiable { let id = UUID(); let text: String }
struct NewEntryContext: Identifiable { let id = UUID(); var day: String }

extension View {
    @ViewBuilder
    func miuZoomSource<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) { self.matchedTransitionSource(id: id, in: namespace) }
        else { self }
    }
    @ViewBuilder
    func miuZoomDestination<ID: Hashable>(_ id: ID, in namespace: Namespace.ID, enabled: Bool) -> some View {
        if #available(iOS 18.0, *), enabled { self.navigationTransition(.zoom(sourceID: id, in: namespace)) }
        else { self }
    }
}
